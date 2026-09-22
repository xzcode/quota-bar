import Foundation

/// Domain model used by SwiftUI; it deliberately does not expose JSON-RPC DTOs.
public struct QuotaBucket: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String?
    public let normalModelSlug: String?
    public let windows: [QuotaWindow]

    public init(id: String, name: String?, normalModelSlug: String?, windows: [QuotaWindow]) {
        self.id = id
        self.name = name
        self.normalModelSlug = normalModelSlug
        self.windows = windows
    }
}

/// A single primary or secondary rate-limit window.
public struct QuotaWindow: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let usedPercent: Int
    public let windowDurationMinutes: Int?
    public let resetsAt: Date?
    public let kind: WindowKind

    public enum WindowKind: String, Codable, Sendable {
        case primary
        case secondary
    }

    public init(id: String, usedPercent: Int, windowDurationMinutes: Int?, resetsAt: Date?, kind: WindowKind) {
        self.id = id
        self.usedPercent = usedPercent
        self.windowDurationMinutes = windowDurationMinutes
        self.resetsAt = resetsAt
        self.kind = kind
    }

    public var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

/// Cached snapshot stored in UserDefaults without any authentication data.
public struct QuotaSnapshot: Codable, Equatable, Sendable {
    public let buckets: [QuotaBucket]
    public let capturedAt: Date

    public init(buckets: [QuotaBucket], capturedAt: Date) {
        self.buckets = buckets
        self.capturedAt = capturedAt
    }
}

/// Safe parser metadata suitable for DEBUG logs without account credentials.
public struct RateLimitDiagnostic: Equatable, Sendable {
    public enum Source: String, Equatable, Sendable {
        case grouped
        case legacy
        case direct
        case none
    }

    public let rootKeys: [String]
    public let source: Source
    public let groupedBucketCount: Int
    public let parsedBucketCount: Int
    public let skippedBucketCount: Int
    public let windowSummaries: [String]

    public var hasRecognizedRateLimitKeys: Bool {
        rootKeys.contains("rateLimitsByLimitId") || rootKeys.contains("rateLimits")
    }

    /// Only field names, counts, and window values are included in the log.
    public var summary: String {
        "rootKeys=\(rootKeys), source=\(source.rawValue), groupedBucketCount=\(groupedBucketCount), parsedBucketCount=\(parsedBucketCount), skippedBucketCount=\(skippedBucketCount), windows=\(windowSummaries)"
    }
}

/// Parser output keeps a safe diagnostic next to the domain buckets.
public struct RateLimitParseResult: Equatable, Sendable {
    public let buckets: [QuotaBucket]
    public let diagnostic: RateLimitDiagnostic

    public init(buckets: [QuotaBucket], diagnostic: RateLimitDiagnostic) {
        self.buckets = buckets
        self.diagnostic = diagnostic
    }
}

/// Converts permissive JSON-RPC payloads into stable domain models.
public enum RateLimitParser {
    public static func parse(result: JSONValue) -> [QuotaBucket] {
        parseDetailed(result: result).buckets
    }

    public static func parseDetailed(result: JSONValue) -> RateLimitParseResult {
        guard let resultObject = result.objectValue else {
            return makeResult(
                buckets: [],
                source: .none,
                groupedBucketCount: 0,
                skippedBucketCount: 0,
                rootKeys: [],
                windowSummaries: []
            )
        }

        let rootKeys = resultObject.keys.sorted()
        if let groupedValue = resultObject["rateLimitsByLimitId"],
           let grouped = groupedValue.objectValue,
           !grouped.isEmpty {
            let parsed = grouped.compactMap { id, value in
                parseBucket(id: id, value: value)
            }
            if !parsed.isEmpty {
                return makeResult(
                    buckets: parsed,
                    source: .grouped,
                    groupedBucketCount: grouped.count,
                    skippedBucketCount: grouped.count - parsed.count,
                    rootKeys: rootKeys,
                    windowSummaries: summaries(for: parsed)
                )
            }
        }

        if let legacy = resultObject["rateLimits"],
           let bucket = parseBucket(id: "codex", value: legacy) {
            return makeResult(
                buckets: [bucket],
                source: .legacy,
                groupedBucketCount: 0,
                skippedBucketCount: 0,
                rootKeys: rootKeys,
                windowSummaries: summaries(for: [bucket])
            )
        }

        // Some app-server revisions return the rate-limit object directly.
        if let direct = parseBucket(id: "codex", value: result) {
            return makeResult(
                buckets: [direct],
                source: .direct,
                groupedBucketCount: 0,
                skippedBucketCount: 0,
                rootKeys: rootKeys,
                windowSummaries: summaries(for: [direct])
            )
        }

        return makeResult(
            buckets: [],
            source: .none,
            groupedBucketCount: resultObject["rateLimitsByLimitId"]?.objectValue?.count ?? 0,
            skippedBucketCount: 0,
            rootKeys: rootKeys,
            windowSummaries: []
        )
    }

    private static func makeResult(
        buckets: [QuotaBucket],
        source: RateLimitDiagnostic.Source,
        groupedBucketCount: Int,
        skippedBucketCount: Int,
        rootKeys: [String],
        windowSummaries: [String]
    ) -> RateLimitParseResult {
        let sortedBuckets = buckets.sorted { lhs, rhs in
            if lhs.id == "codex" { return true }
            if rhs.id == "codex" { return false }
            return lhs.id < rhs.id
        }
        return RateLimitParseResult(
            buckets: sortedBuckets,
            diagnostic: RateLimitDiagnostic(
                rootKeys: rootKeys,
                source: source,
                groupedBucketCount: groupedBucketCount,
                parsedBucketCount: sortedBuckets.count,
                skippedBucketCount: skippedBucketCount,
                windowSummaries: windowSummaries
            )
        )
    }

    private static func parseBucket(id: String, value: JSONValue) -> QuotaBucket? {
        guard let object = value.objectValue else { return nil }
        let primary = parseWindow(name: "primary", value: object["primary"])
        let secondary = parseWindow(name: "secondary", value: object["secondary"])
        let windows = [primary, secondary].compactMap { $0 }
        guard !windows.isEmpty else { return nil }

        return QuotaBucket(
            id: string(in: object, key: "limitId") ?? id,
            name: string(in: object, key: "limitName"),
            normalModelSlug: string(in: object, key: "normalModelSlug"),
            windows: windows
        )
    }

    private static func parseWindow(name: String, value: JSONValue?) -> QuotaWindow? {
        guard let object = value?.objectValue,
              let used = number(in: object, key: "usedPercent") else {
            return nil
        }

        let duration = number(in: object, key: "windowDurationMins").map { Int($0) }
        return QuotaWindow(
            id: name,
            usedPercent: Int(used.rounded()),
            windowDurationMinutes: duration,
            resetsAt: parseDate(object["resetsAt"]),
            kind: name == "primary" ? .primary : .secondary
        )
    }

    private static func string(in object: [String: JSONValue], key: String) -> String? {
        object[key]?.stringValue
    }

    private static func number(in object: [String: JSONValue], key: String) -> Double? {
        if let number = object[key]?.doubleValue { return number }
        if let string = object[key]?.stringValue { return Double(string) }
        return nil
    }

    private static func parseDate(_ value: JSONValue?) -> Date? {
        if let seconds = value?.doubleValue { return Date(timeIntervalSince1970: seconds) }
        if let string = value?.stringValue, let seconds = Double(string) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value?.stringValue {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }

    private static func summaries(for buckets: [QuotaBucket]) -> [String] {
        buckets.flatMap { bucket in
            bucket.windows.map { window in
                "bucket=\(bucket.id),\(window.kind.rawValue){usedPercent=\(window.usedPercent),windowDurationMins=\(window.windowDurationMinutes.map(String.init) ?? "null"),resetsAtPresent=\(window.resetsAt != nil)}"
            }
        }
    }
}
