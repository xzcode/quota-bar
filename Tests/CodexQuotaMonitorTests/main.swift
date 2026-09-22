import Foundation
import CodexQuotaCore

/// Dependency-free test runner used when only Apple's Command Line Tools are installed.
@main
struct CodexQuotaMonitorTests {
    static func main() {
        let tests: [(String, () throws -> Void)] = [
            ("grouped primary and secondary windows", testGroupedWindows),
            ("null grouped map fallback", testNullGroupedMapFallback),
            ("empty grouped map fallback", testEmptyGroupedMapFallback),
            ("multiple buckets and unknown fields", testMultipleBuckets),
            ("missing windows diagnostic", testMissingWindowsDiagnostic),
            ("required duration formatting", testDurationFormatting),
            ("countdown formatting", testCountdownFormatting),
            ("missing reset time formatting", testMissingResetTime),
            ("Codex response without jsonrpc", testResponseWithoutJSONRPC),
            ("notification method and params", testNotification)
        ]

        var failures = 0
        for (name, test) in tests {
            do {
                try test()
                print("PASS: \(name)")
            } catch {
                failures += 1
                print("FAIL: \(name) — \(error.localizedDescription)")
            }
        }

        if failures > 0 {
            print("\(failures) test(s) failed")
            exit(1)
        }
        print("All \(tests.count) tests passed")
    }

    private static func testGroupedWindows() throws {
        let result = try decodeJSON("""
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": { "usedPercent": 20, "windowDurationMins": 300, "resetsAt": 2000000000 },
            "secondary": { "usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 2000100000 }
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "primary": { "usedPercent": 20, "windowDurationMins": 300, "resetsAt": 2000000000 },
              "secondary": { "usedPercent": 40, "windowDurationMins": 10080, "resetsAt": 2000100000 }
            }
          }
        }
        """)
        let parsed = RateLimitParser.parseDetailed(result: result)
        try expect(parsed.diagnostic.source == .grouped, "expected grouped source")
        try expect(parsed.buckets.count == 1, "expected one bucket")
        try expect(parsed.buckets[0].windows.map(\.remainingPercent) == [80, 60], "expected 80% and 60% remaining")
    }

    private static func testNullGroupedMapFallback() throws {
        let result = try decodeJSON("""
        { "rateLimitsByLimitId": null, "rateLimits": {
          "primary": { "usedPercent": 20, "windowDurationMins": 300 }
        } }
        """)
        let parsed = RateLimitParser.parseDetailed(result: result)
        try expect(parsed.diagnostic.source == .legacy, "expected legacy fallback")
        try expect(parsed.buckets.first?.windows.first?.remainingPercent == 80, "expected 80% remaining")
    }

    private static func testEmptyGroupedMapFallback() throws {
        let result = try decodeJSON("""
        { "rateLimitsByLimitId": {}, "rateLimits": {
          "primary": { "usedPercent": 20, "windowDurationMins": 300 }
        } }
        """)
        let parsed = RateLimitParser.parseDetailed(result: result)
        try expect(parsed.diagnostic.source == .legacy, "expected legacy fallback")
        try expect(parsed.buckets.count == 1, "expected one fallback bucket")
    }

    private static func testMultipleBuckets() throws {
        let result = try decodeJSON("""
        { "rateLimitsByLimitId": {
          "base_model_inference": {
            "limitId": "base_model_inference",
            "primary": { "usedPercent": 0, "windowDurationMins": 10080, "unknown": "ignored" }
          },
          "codex": {
            "limitId": "codex",
            "primary": { "usedPercent": 100, "windowDurationMins": 300 },
            "secondary": null
          }
        } }
        """)
        let parsed = RateLimitParser.parseDetailed(result: result)
        try expect(parsed.buckets.map(\.id) == ["codex", "base_model_inference"], "expected both buckets")
        try expect(parsed.buckets[0].windows[0].remainingPercent == 0, "expected exhausted codex bucket")
        try expect(parsed.buckets[1].windows[0].remainingPercent == 100, "expected unused secondary bucket")
    }

    private static func testMissingWindowsDiagnostic() throws {
        let result = try decodeJSON("""
        { "rateLimitsByLimitId": {}, "rateLimits": { "credits": null } }
        """)
        let parsed = RateLimitParser.parseDetailed(result: result)
        try expect(parsed.buckets.isEmpty, "expected no buckets")
        try expect(parsed.diagnostic.source == .none, "expected no parser source")
        try expect(parsed.diagnostic.hasRecognizedRateLimitKeys, "expected recognized rate-limit keys")
    }

    private static func testDurationFormatting() throws {
        try expect(QuotaFormatter.windowTitle(minutes: 300) == "5 小时额度", "300 minute format")
        try expect(QuotaFormatter.windowTitle(minutes: 10080) == "周额度", "weekly format")
        try expect(QuotaFormatter.windowTitle(minutes: 60) == "1 小时额度", "hour format")
        try expect(QuotaFormatter.windowTitle(minutes: 1440) == "24 小时额度", "day format")
        try expect(QuotaFormatter.windowTitle(minutes: 4320) == "3 天额度", "three day format")
    }

    private static func testCountdownFormatting() throws {
        let now = Date(timeIntervalSince1970: 0)
        try expect(QuotaFormatter.countdown(to: now.addingTimeInterval(45 * 60), now: now) == "45 分钟后重置", "45 minute countdown")
        try expect(QuotaFormatter.countdown(to: now.addingTimeInterval(80 * 60), now: now) == "1 小时 20 分后重置", "80 minute countdown")
        try expect(QuotaFormatter.countdown(to: now.addingTimeInterval((2 * 24 + 3) * 60 * 60), now: now) == "2 天 3 小时后重置", "multi-day countdown")
        try expect(QuotaFormatter.countdown(to: now, now: now) == "已重置 / 时间已到", "expired countdown")
    }

    private static func testMissingResetTime() throws {
        try expect(QuotaFormatter.countdown(to: nil) == "重置时间未知", "missing reset time")
    }

    private static func testResponseWithoutJSONRPC() throws {
        let data = Data("""
        { "id": 2, "result": { "rateLimits": { "primary": {
          "usedPercent": 7, "windowDurationMins": 300
        } } } }
        """.utf8)
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        try expect(response.jsonrpc == nil, "jsonrpc should be optional")
        try expect(response.id == 2, "expected response id 2")
        try expect(response.result != nil, "expected response result")
    }

    private static func testNotification() throws {
        let data = Data("""
        { "method": "remoteControl/status/changed", "params": { "status": "disabled" } }
        """.utf8)
        let response = try JSONDecoder().decode(JSONRPCResponse.self, from: data)
        try expect(response.method == "remoteControl/status/changed", "expected notification method")
        try expect(response.params?.objectValue?["status"]?.stringValue == "disabled", "expected notification params")
        try expect(response.id == nil, "notification should not have an id")
    }

    private static func decodeJSON(_ string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TestFailure(message) }
    }
}

private struct TestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
