import Foundation
import SwiftUI
import CodexQuotaCore

/// User-visible connection and quota status.
enum QuotaStatus: Equatable, Sendable {
    case loading
    case normal
    case low
    case critical
    case notAuthenticated
    case serviceError
    case notInstalled
    case noWindows
    case appServerStartFailed
    case initializeFailed
    case rateLimitsReadFailed
    case unrecognizedResponse

    var label: String {
        switch self {
        case .loading: return "正在刷新"
        case .normal: return "正常"
        case .low: return "额度偏低"
        case .critical: return "即将耗尽"
        case .notAuthenticated: return "Codex 未登录"
        case .serviceError: return "Codex 服务异常"
        case .notInstalled: return "未检测到 Codex CLI"
        case .noWindows: return "未返回额度窗口"
        case .appServerStartFailed: return "app-server 启动失败"
        case .initializeFailed: return "Codex 初始化失败"
        case .rateLimitsReadFailed: return "额度请求失败"
        case .unrecognizedResponse: return "额度响应无法识别"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .green
        case .low: return .orange
        case .critical, .serviceError, .notAuthenticated, .notInstalled, .appServerStartFailed, .initializeFailed, .rateLimitsReadFailed, .unrecognizedResponse: return .red
        case .loading, .noWindows: return .secondary
        }
    }
}

/// Main-thread view model; all process work remains in the actor client.
@MainActor
final class QuotaViewModel: ObservableObject {
    @Published private(set) var snapshot: QuotaSnapshot?
    @Published private(set) var status: QuotaStatus = .loading
    @Published private(set) var isRefreshing = false
    @Published private(set) var isStale = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var transientNotice: String?
    @Published private(set) var burnRate: BurnRateSnapshot = .unknown
    @Published private(set) var isParticlePulseActive = false
    @Published private(set) var diagnosticDetails: String? = nil

    private let client: CodexAppServerClient
    private let cache = QuotaCacheStore()
    private var burnRateHistory = BurnRateHistoryStore()
    private var particleActivityTask: Task<Void, Never>?

    init(client: CodexAppServerClient) {
        self.client = client
        snapshot = cache.load()
        if snapshot != nil {
            isStale = true
            status = statusForCurrentSnapshot()
            burnRate = burnRateHistory.current(for: snapshot)
        }
    }

    /// Refreshes from app-server and preserves a cached snapshot after errors.
    @discardableResult
    func refresh(manual: Bool) async -> Bool {
        // Manual refreshes share the same in-flight request instead of
        // opening a second app-server RPC while the scheduler is working.
        guard !isRefreshing else { return false }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let buckets = try await client.fetchRateLimits()
            let previousSnapshot = snapshot
            let newSnapshot = QuotaSnapshot(buckets: buckets, capturedAt: .now)
            snapshot = newSnapshot
            cache.save(newSnapshot)
            let burnRateUpdate = burnRateHistory.record(
                snapshot: newSnapshot,
                previousSnapshot: previousSnapshot
            )
            burnRate = burnRateUpdate.snapshot
            if burnRateUpdate.didIncreaseUsage {
                startParticleActivityPulse()
            }
            isStale = false
            status = buckets.isEmpty ? .noWindows : statusForCurrentSnapshot()
            transientNotice = nil
            diagnosticDetails = "status=success"
            return true
        } catch let error as CodexClientError {
            errorMessage = error.localizedDescription
            diagnosticDetails = error.diagnosticDescription
            isStale = true
            status = statusFor(error)
            return false
        } catch {
            errorMessage = "暂时无法获取额度"
            diagnosticDetails = "status=transport_error"
            isStale = true
            status = .serviceError
            return false
        }
    }

    func stopClient() async {
        particleActivityTask?.cancel()
        particleActivityTask = nil
        isParticlePulseActive = false
        await client.stop()
    }

    func setTransientNotice(_ notice: String) {
        transientNotice = notice
    }

    var primaryBucket: QuotaBucket? {
        guard let buckets = snapshot?.buckets else { return nil }
        return buckets.first(where: { $0.id == "codex" }) ?? buckets.first
    }

    var allWindows: [QuotaWindow] {
        snapshot?.buckets.flatMap(\.windows) ?? []
    }

    var menuBarPercentageText: String {
        guard let minimum = collapsedRemainingPercent else { return "—" }
        return "\(minimum)%"
    }

    /// The compact bar represents the most dangerous window in the primary
    /// Codex bucket, with a safe fallback for older response shapes.
    var collapsedRemainingPercent: Int? {
        primaryBucket?.windows.map(\.remainingPercent).min()
            ?? allWindows.map(\.remainingPercent).min()
    }

    /// Uses the reserve balance only after both ordinary Codex windows are exhausted.
    var collapsedDisplayRemainingPercent: Int? {
        reserveFallbackPercent ?? collapsedRemainingPercent
    }

    /// Shows ordinary windows as bare percentages, or marks the reserve balance with R.
    var collapsedQuotaSummary: String? {
        if let reserve = reserveFallbackPercent {
            return "R · \(reserve)%"
        }

        guard let windows = primaryBucket?.windows,
              windows.contains(where: { $0.windowDurationMinutes == 300 }) else {
            return nil
        }

        let fiveHourWindows = windows.filter { $0.windowDurationMinutes == 300 }
        let weeklyWindows = windows.filter { $0.windowDurationMinutes == 10080 }
        let otherWindows = windows.filter { $0.windowDurationMinutes != 300 && $0.windowDurationMinutes != 10080 }
        return (fiveHourWindows + weeklyWindows + otherWindows)
            .map { "\($0.remainingPercent)%" }
            .joined(separator: " · ")
    }

    /// Tooltip content intentionally exposes only quota percentages.
    var compactTooltipText: String {
        if let reserve = reserveFallbackPercent {
            return "GPT Reserve：\(reserve)%"
        }

        guard let bucket = primaryBucket else { return "额度暂时不可用" }
        let parts = bucket.windows.map { window in
            "\(QuotaFormatter.compactWindowTitle(minutes: window.windowDurationMinutes))：\(window.remainingPercent)%"
        }
        return parts.joined(separator: " / ")
    }

    private var reserveFallbackPercent: Int? {
        guard let windows = primaryBucket?.windows,
              let fiveHour = windows.first(where: { $0.windowDurationMinutes == 300 }),
              let weekly = windows.first(where: { $0.windowDurationMinutes == 10080 }),
              fiveHour.remainingPercent == 0,
              weekly.remainingPercent == 0,
              let reserveBucket = snapshot?.buckets.first(where: isReserveBucket),
              let remaining = reserveBucket.windows.map(\.remainingPercent).min() else {
            return nil
        }
        return remaining
    }

    /// Recognizes the reserve pool by its explicit server name or known bucket id.
    private func isReserveBucket(_ bucket: QuotaBucket) -> Bool {
        let id = bucket.id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = bucket.name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return name == "gpt-reserve" || id == "gpt-reserve" || (id == "base_model_inference" && name == nil)
    }

    var footerStatusText: String {
        if isStale, snapshot != nil { return "数据可能已过期" }
        return status.label
    }

    /// Safe text for the context-menu copy action; it contains no raw RPC data.
    var diagnosticText: String {
        var lines = [
            "status=\(status.label)",
            "stale=\(isStale)",
            "lastUpdated=\(lastUpdatedText)",
            "burnRate=\(burnRate.level.rawValue)"
        ]
        if let errorMessage {
            lines.append("error=\(errorMessage)")
        }
        if let diagnosticDetails {
            lines.append(diagnosticDetails)
        }
        return lines.joined(separator: "\n")
    }

    var lastUpdatedText: String {
        QuotaFormatter.relativeUpdate(snapshot?.capturedAt)
    }

    /// Briefly signals fresh quota use without treating the rolling rate as live activity.
    private func startParticleActivityPulse() {
        particleActivityTask?.cancel()
        isParticlePulseActive = true
        particleActivityTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                return
            }
            guard let self else { return }
            self.isParticlePulseActive = false
            self.particleActivityTask = nil
        }
    }

    var staleMessage: String? {
        guard isStale, let capturedAt = snapshot?.capturedAt else { return nil }
        let age = Date().timeIntervalSince(capturedAt)
        if age > 24 * 60 * 60 {
            return "数据已过期，显示的是 \(QuotaFormatter.relativeUpdate(capturedAt)) 的缓存数据"
        }
        return "数据可能已过期，显示的是 \(QuotaFormatter.relativeUpdate(capturedAt)) 的缓存数据"
    }

    private func statusForCurrentSnapshot() -> QuotaStatus {
        guard let minimum = allWindows.map(\.remainingPercent).min() else { return .noWindows }
        if minimum <= 10 { return .critical }
        if minimum <= 25 { return .low }
        return .normal
    }

    private func statusFor(_ error: CodexClientError) -> QuotaStatus {
        switch error {
        case .notInstalled: return .notInstalled
        case .notAuthenticated: return .notAuthenticated
        case .appServerStartFailed: return .appServerStartFailed
        case .initializeFailed: return .initializeFailed
        case .rateLimitsReadFailed: return .rateLimitsReadFailed
        case .unrecognizedResponse: return .unrecognizedResponse
        case .transport: return .serviceError
        }
    }
}

/// UserDefaults cache containing only the last successful quota domain model.
private struct QuotaCacheStore {
    func load() -> QuotaSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: SettingsKey.cachedSnapshot) else { return nil }
        return try? JSONDecoder().decode(QuotaSnapshot.self, from: data)
    }

    func save(_ snapshot: QuotaSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: SettingsKey.cachedSnapshot)
    }
}
