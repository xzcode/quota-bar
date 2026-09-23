import Foundation

/// Visual activity based on real local token deltas, independent from quota burn rate.
public enum TokenActivityLevel: String, Codable, Equatable, Sendable {
    case calm
    case active
    case fast
    case veryFast

    public var label: String {
        switch self {
        case .calm: return "平稳"
        case .active: return "活跃"
        case .fast: return "较快"
        case .veryFast: return "很快"
        }
    }
}

/// Privacy-safe aggregate exposed to the UI; it never contains rollout text.
public struct LocalTokenUsageSnapshot: Sendable, Equatable {
    public let capturedAt: Date
    public let todayTotalTokens: Int64
    public let todayInputTokens: Int64
    public let todayCachedInputTokens: Int64
    public let todayOutputTokens: Int64
    public let recentTokensPerMinute: Double
    public let lastUsageAt: Date?
    public let activityLevel: TokenActivityLevel
    public let isAvailable: Bool

    public init(
        capturedAt: Date,
        todayTotalTokens: Int64,
        todayInputTokens: Int64,
        todayCachedInputTokens: Int64,
        todayOutputTokens: Int64,
        recentTokensPerMinute: Double,
        lastUsageAt: Date?,
        activityLevel: TokenActivityLevel,
        isAvailable: Bool
    ) {
        self.capturedAt = capturedAt
        self.todayTotalTokens = todayTotalTokens
        self.todayInputTokens = todayInputTokens
        self.todayCachedInputTokens = todayCachedInputTokens
        self.todayOutputTokens = todayOutputTokens
        self.recentTokensPerMinute = recentTokensPerMinute
        self.lastUsageAt = lastUsageAt
        self.activityLevel = activityLevel
        self.isAvailable = isAvailable
    }

    /// Represents unavailable local history without turning it into an app error.
    public static func unavailable(at date: Date = .now) -> LocalTokenUsageSnapshot {
        LocalTokenUsageSnapshot(
            capturedAt: date,
            todayTotalTokens: 0,
            todayInputTokens: 0,
            todayCachedInputTokens: 0,
            todayOutputTokens: 0,
            recentTokensPerMinute: 0,
            lastUsageAt: nil,
            activityLevel: .calm,
            isAvailable: false
        )
    }
}

/// One token_count event decoded from a rollout line, with no other session content retained.
public struct RolloutTokenUsageEvent: Sendable, Equatable {
    public let timestamp: Date
    public let totalTokens: Int64
    public let inputTokens: Int64?
    public let cachedInputTokens: Int64?
    public let outputTokens: Int64?

    public init(
        timestamp: Date,
        totalTokens: Int64,
        inputTokens: Int64? = nil,
        cachedInputTokens: Int64? = nil,
        outputTokens: Int64? = nil
    ) {
        self.timestamp = timestamp
        self.totalTokens = max(0, totalTokens)
        self.inputTokens = inputTokens.map { max(0, $0) }
        self.cachedInputTokens = cachedInputTokens.map { max(0, $0) }
        self.outputTokens = outputTokens.map { max(0, $0) }
    }
}

/// Extracts only token_count payloads; unknown event fields are skipped by Codable.
public enum RolloutTokenParser {
    public static func parse(line: Data) -> RolloutTokenUsageEvent? {
        guard let envelope = try? JSONDecoder().decode(RolloutEnvelope.self, from: line),
              let payload = envelope.payload,
              payload.type == "token_count",
              let usage = payload.info?.totalTokenUsage,
              let timestamp = parseTimestamp(envelope.timestamp ?? payload.timestamp) else {
            return nil
        }

        let total = usage.totalTokens ?? sum(usage.inputTokens, usage.outputTokens)
        guard let total else { return nil }
        return RolloutTokenUsageEvent(
            timestamp: timestamp,
            totalTokens: total,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.cachedInputTokens,
            outputTokens: usage.outputTokens
        )
    }

    /// ISO-8601 rollout timestamps may or may not include fractional seconds.
    private static func parseTimestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    /// Input includes cached input, so only input plus output is a valid fallback total.
    private static func sum(_ input: Int64?, _ output: Int64?) -> Int64? {
        guard input != nil || output != nil else { return nil }
        let left = max(0, input ?? 0)
        let right = max(0, output ?? 0)
        return left > Int64.max - right ? Int64.max : left + right
    }
}

/// Buffers JSONL bytes until a complete newline arrives, preserving only the unfinished line.
public struct JSONLLineBuffer: Sendable {
    private var partialLine = Data()

    public init() {}

    public mutating func append(_ bytes: Data) -> [Data] {
        partialLine.append(bytes)
        var completeLines: [Data] = []

        while let newline = partialLine.firstIndex(of: 0x0A) {
            var line = Data(partialLine[..<newline])
            if line.last == 0x0D { line.removeLast() }
            if !line.isEmpty { completeLines.append(line) }
            partialLine.removeSubrange(...newline)
        }
        return completeLines
    }

    public var pendingByteCount: Int { partialLine.count }
}

/// Applies cumulative token_count samples to independent session baselines and daily totals.
public struct LocalTokenUsageAccumulator: Sendable {
    private struct Counters: Sendable {
        var total: Int64
        var input: Int64?
        var cachedInput: Int64?
        var output: Int64?
    }

    private struct DeltaEvent: Sendable {
        let timestamp: Date
        let tokens: Int64
    }

    private struct SessionState: Sendable {
        var lastCounters: Counters?
        var todayTotal: Int64 = 0
        var todayInput: Int64 = 0
        var todayCachedInput: Int64 = 0
        var todayOutput: Int64 = 0
        var lastUsageAt: Date?
        var events: [DeltaEvent] = []
        var hasTokenData = false
    }

    private var sessions: [String: SessionState] = [:]
    private var currentDayStart: Date?

    public init() {}

    /// Records a cumulative sample, counting only its positive delta for the local calendar day.
    public mutating func record(
        _ event: RolloutTokenUsageEvent,
        sessionID: String,
        sessionStartedAt: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let today = calendar.startOfDay(for: now)
        resetDailyCountersIfNeeded(startOfDay: today)
        var state = sessions[sessionID, default: SessionState()]
        state.hasTokenData = true

        let current = Counters(
            total: event.totalTokens,
            input: event.inputTokens,
            cachedInput: event.cachedInputTokens,
            output: event.outputTokens
        )
        let isFirstSample = state.lastCounters == nil
        let isNewSessionToday = isFirstSample
            && sessionStartedAt.map { calendar.isDate($0, inSameDayAs: event.timestamp) } == true
        let previous = state.lastCounters
        let totalDelta = positiveDelta(current.total, previous?.total, countFirstSample: isNewSessionToday)
        let inputDelta = positiveDelta(current.input, previous?.input, countFirstSample: isNewSessionToday)
        let cachedDelta = positiveDelta(current.cachedInput, previous?.cachedInput, countFirstSample: isNewSessionToday)
        let outputDelta = positiveDelta(current.output, previous?.output, countFirstSample: isNewSessionToday)
        state.lastCounters = current

        if event.timestamp >= today, event.timestamp <= now {
            state.todayTotal = adding(state.todayTotal, totalDelta)
            state.todayInput = adding(state.todayInput, inputDelta)
            state.todayCachedInput = adding(state.todayCachedInput, cachedDelta)
            state.todayOutput = adding(state.todayOutput, outputDelta)
            if totalDelta > 0 {
                state.lastUsageAt = event.timestamp
                state.events.append(DeltaEvent(timestamp: event.timestamp, tokens: totalDelta))
            }
        }
        sessions[sessionID] = state
    }

    /// Removes a truncated/replaced rollout's contribution before rebuilding its baseline.
    public mutating func removeSession(_ sessionID: String) {
        sessions.removeValue(forKey: sessionID)
    }

    /// Produces the current snapshot and derives rolling activity from the last two minutes.
    public mutating func snapshot(now: Date = .now, calendar: Calendar = .current) -> LocalTokenUsageSnapshot {
        let today = calendar.startOfDay(for: now)
        resetDailyCountersIfNeeded(startOfDay: today)
        let eventCutoff = now.addingTimeInterval(-5 * 60)

        var total: Int64 = 0
        var input: Int64 = 0
        var cachedInput: Int64 = 0
        var output: Int64 = 0
        var latestUsage: Date?
        var recentTokens: Int64 = 0
        let rateCutoff = now.addingTimeInterval(-2 * 60)
        var available = false

        for id in Array(sessions.keys) {
            guard var state = sessions[id] else { continue }
            state.events.removeAll { $0.timestamp < eventCutoff || $0.timestamp > now }
            sessions[id] = state
            total = adding(total, state.todayTotal)
            input = adding(input, state.todayInput)
            cachedInput = adding(cachedInput, state.todayCachedInput)
            output = adding(output, state.todayOutput)
            available = available || state.hasTokenData
            if let usageAt = state.lastUsageAt, latestUsage.map({ usageAt > $0 }) ?? true {
                latestUsage = usageAt
            }
            for event in state.events where event.timestamp >= rateCutoff {
                recentTokens = adding(recentTokens, event.tokens)
            }
        }

        let rate = Double(recentTokens) / 2
        let activeRecently = latestUsage.map { now.timeIntervalSince($0) <= 90 } ?? false
        let level = TokenActivityPolicy.level(tokensPerMinute: rate, hasRecentUsage: activeRecently)
        return LocalTokenUsageSnapshot(
            capturedAt: now,
            todayTotalTokens: total,
            todayInputTokens: input,
            todayCachedInputTokens: cachedInput,
            todayOutputTokens: output,
            recentTokensPerMinute: rate,
            lastUsageAt: latestUsage,
            activityLevel: level,
            isAvailable: available
        )
    }

    private mutating func resetDailyCountersIfNeeded(startOfDay: Date) {
        guard currentDayStart != startOfDay else { return }
        currentDayStart = startOfDay
        for id in Array(sessions.keys) {
            guard var state = sessions[id] else { continue }
            state.todayTotal = 0
            state.todayInput = 0
            state.todayCachedInput = 0
            state.todayOutput = 0
            state.lastUsageAt = nil
            state.events.removeAll(keepingCapacity: true)
            sessions[id] = state
        }
    }

    private func positiveDelta(_ current: Int64?, _ previous: Int64?, countFirstSample: Bool) -> Int64 {
        guard let current else { return 0 }
        guard let previous else { return countFirstSample ? current : 0 }
        return current > previous ? current - previous : 0
    }

    private func adding(_ left: Int64, _ right: Int64) -> Int64 {
        guard right > 0, left <= Int64.max - right else { return right > 0 ? Int64.max : left }
        return left + right
    }
}

/// Central thresholds keep token motion policy distinct from quota-based burn-rate policy.
public enum TokenActivityPolicy {
    public static let fastThreshold = 100_000.0
    public static let veryFastThreshold = 500_000.0

    public static func level(tokensPerMinute: Double, hasRecentUsage: Bool) -> TokenActivityLevel {
        guard hasRecentUsage else { return .calm }
        if tokensPerMinute >= veryFastThreshold { return .veryFast }
        if tokensPerMinute >= fastThreshold { return .fast }
        return .active
    }
}

/// Compact decimal formatter shared by the capsule and the expanded-card tooltip.
public enum LocalTokenUsageFormatter {
    public static func format(_ tokens: Int64) -> String {
        let value = max(0, tokens)
        guard value >= 1_000 else { return grouped(value) }

        var scaled = Double(value) / 1_000
        var suffix = "K"
        if scaled >= 1_000 {
            scaled /= 1_000
            suffix = "M"
        }
        if scaled >= 1_000 {
            scaled /= 1_000
            suffix = "B"
        }
        let decimals = suffix == "K"
            ? (scaled < 10 ? 1 : (scaled < 100 ? 1 : 0))
            : (scaled < 10 ? 2 : (scaled < 100 ? 1 : 0))
        let rounded = (scaled * pow(10, Double(decimals))).rounded() / pow(10, Double(decimals))
        if rounded >= 1_000, suffix == "K" { return "1M" }
        let formatted = String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, rounded)
        let trimmed = formatted.contains(".") ? formatted.replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression).replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression) : formatted
        return "\(trimmed)\(suffix)"
    }

    private static func grouped(_ value: Int64) -> String {
        let digits = String(value)
        var result = ""
        for (index, character) in digits.reversed().enumerated() {
            if index > 0, index.isMultiple(of: 3) { result.append(",") }
            result.append(character)
        }
        return String(result.reversed())
    }
}

private struct RolloutEnvelope: Decodable {
    let timestamp: String?
    let payload: RolloutPayload?
}

private struct RolloutPayload: Decodable {
    let type: String?
    let timestamp: String?
    let info: RolloutInfo?

    private enum CodingKeys: String, CodingKey { case type, timestamp, info }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        // Avoid decoding arbitrary event payloads; only token_count's aggregate is retained.
        info = type == "token_count" ? try container.decodeIfPresent(RolloutInfo.self, forKey: .info) : nil
    }
}

private struct RolloutInfo: Decodable {
    let totalTokenUsage: RolloutUsageCounters?

    private enum CodingKeys: String, CodingKey { case totalTokenUsage = "total_token_usage" }
}

private struct RolloutUsageCounters: Decodable {
    let totalTokens: Int64?
    let inputTokens: Int64?
    let cachedInputTokens: Int64?
    let outputTokens: Int64?

    private enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
    }
}
