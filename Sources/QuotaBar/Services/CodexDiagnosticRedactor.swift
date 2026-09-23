import Foundation

/// Removes credential-like values before an error reaches UI, logs, or output.
enum CodexDiagnosticRedactor {
    static func message(_ rawMessage: String) -> String {
        var value = rawMessage
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")

        let labeledSecret = #"(?i)\b(authorization|cookie|access[_-]?token|refresh[_-]?token|id[_-]?token|token|account[_-]?id|account\s+id|user[_-]?id|user\s+id)\s*[:=]\s*("[^"]*"|'[^']*'|[^\s,;]+)"#
        value = replace(pattern: labeledSecret, in: value, with: "$1=<redacted>")
        value = replace(pattern: #"(?i)\bbearer\s+[A-Za-z0-9._~+/=-]+"#, in: value, with: "Bearer <redacted>")
        value = replace(pattern: #"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b"#, in: value, with: "<redacted>")
        value = replace(pattern: #"(?i)\bauth\.json\b"#, in: value, with: "<redacted-file>")

        // Keep diagnostic text concise and prevent an unexpectedly large
        // server message from becoming a UI or log payload.
        if value.count > 300 {
            value = String(value.prefix(300)) + "…"
        }
        return value.isEmpty ? "未知错误" : value
    }

    private static func replace(pattern: String, in value: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return value }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(in: value, range: range, withTemplate: template)
    }
}
