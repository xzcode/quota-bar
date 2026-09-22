import Foundation

/// Domain model used by SwiftUI; it deliberately does not expose JSON-RPC DTOs.
struct QuotaBucket: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let name: String?
    let normalModelSlug: String?
    let windows: [QuotaWindow]
}

/// A single primary or secondary rate-limit window.
struct QuotaWindow: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let usedPercent: Int
    let windowDurationMinutes: Int?
    let resetsAt: Date?
    let kind: WindowKind

    enum WindowKind: String, Codable, Sendable {
        case primary
        case secondary
    }

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

/// Cached snapshot stored in UserDefaults without any authentication data.
struct QuotaSnapshot: Codable, Equatable, Sendable {
    let buckets: [QuotaBucket]
    let capturedAt: Date
}

/// Converts the permissive JSON-RPC payload into the stable domain model.
enum RateLimitParser {
    static func parse(result: JSONValue) -> [QuotaBucket] {
        guard let resultObject = result.objectValue else { return [] }

        if let grouped = resultObject["rateLimitsByLimitId"]?.objectValue {
            return grouped.compactMap { id, value in
                parseBucket(id: id, value: value)
            }.sorted { lhs, rhs in
                if lhs.id == "codex" { return true }
                if rhs.id == "codex" { return false }
                return lhs.id < rhs.id
            }
        }

        if let legacy = resultObject["rateLimits"] {
            return parseBucket(id: "codex", value: legacy).map { [$0] } ?? []
        }

        // Some app-server revisions return the rate-limit object directly.
        return parseBucket(id: "codex", value: result).map { [$0] } ?? []
    }

    private static func parseBucket(id: String, value: JSONValue) -> QuotaBucket? {
        guard let object = value.objectValue else { return nil }
        let primary = parseWindow(name: "primary", value: object["primary"])
        let secondary = parseWindow(name: "secondary", value: object["secondary"])
        let windows = [primary, secondary].compactMap { $0 }

        // A bucket with no usable windows is not shown as a misleading empty
        // quota row, but other valid buckets remain available.
        guard !windows.isEmpty else { return nil }
        return QuotaBucket(
            id: id,
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
        let resetsAt = parseDate(object["resetsAt"])
        return QuotaWindow(
            id: name,
            usedPercent: Int(used.rounded()),
            windowDurationMinutes: duration,
            resetsAt: resetsAt,
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
        if let seconds = value?.doubleValue {
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value?.stringValue, let seconds = Double(string) {
            return Date(timeIntervalSince1970: seconds)
        }
        if let string = value?.stringValue {
            return ISO8601DateFormatter().date(from: string)
        }
        return nil
    }
}
