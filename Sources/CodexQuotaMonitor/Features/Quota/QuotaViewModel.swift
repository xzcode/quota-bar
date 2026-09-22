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
        case .low: return .yellow
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

    private let client: CodexAppServerClient
    private let cache = QuotaCacheStore()

    init(client: CodexAppServerClient) {
        self.client = client
        snapshot = cache.load()
        if snapshot != nil {
            isStale = true
            status = statusForCurrentSnapshot()
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
            let newSnapshot = QuotaSnapshot(buckets: buckets, capturedAt: .now)
            snapshot = newSnapshot
            cache.save(newSnapshot)
            isStale = false
            status = buckets.isEmpty ? .noWindows : statusForCurrentSnapshot()
            transientNotice = nil
            return true
        } catch let error as CodexClientError {
            errorMessage = error.localizedDescription
            isStale = true
            status = statusFor(error)
            return false
        } catch {
            errorMessage = "暂时无法获取额度"
            isStale = true
            status = .serviceError
            return false
        }
    }

    func stopClient() async {
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
        guard let minimum = allWindows.map(\.remainingPercent).min() else { return "—" }
        return "\(minimum)%"
    }

    var lastUpdatedText: String {
        QuotaFormatter.relativeUpdate(snapshot?.capturedAt)
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
