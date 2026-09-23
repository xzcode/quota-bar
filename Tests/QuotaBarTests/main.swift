import Foundation
import CodexQuotaCore

/// Dependency-free test runner used when only Apple's Command Line Tools are installed.
@main
struct QuotaBarTests {
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
            ("burn rate level thresholds", testBurnRateLevels),
            ("burn rate reset guard", testBurnRateResetGuard),
            ("local token cumulative counters", testLocalTokenCumulativeCounters),
            ("today session initial counter", testTodaySessionInitialCounter),
            ("local token midnight boundary", testLocalTokenMidnightBoundary),
            ("local token sessions aggregate", testLocalTokenMultipleSessions),
            ("malformed token event ignored", testMalformedTokenEvent),
            ("incomplete rollout line buffer", testIncompleteRolloutLine),
            ("token event unknown fields", testTokenEventUnknownFields),
            ("recent token activity thresholds", testRecentTokenActivity),
            ("idle token activity returns calm", testIdleTokenActivity),
            ("unavailable token data leaves quota parsing intact", testUnavailableTokensDoNotAffectQuota),
            ("local token number formatting", testLocalTokenFormatting),
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

    private static func testBurnRateLevels() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let samples = [
            QuotaUsageSample(timestamp: now.addingTimeInterval(-10 * 60), bucketId: "codex", windowKind: .primary, usedPercent: 20),
            QuotaUsageSample(timestamp: now, bucketId: "codex", windowKind: .primary, usedPercent: 24)
        ]
        let result = BurnRateCalculator.calculate(samples: samples, now: now)
        try expect(abs((result.percentPerMinute ?? 0) - 0.4) < 0.0001, "expected 0.4 percent per minute")
        try expect(result.level == .veryFast, "expected veryFast level")
        try expect(BurnRateCalculator.level(for: 0.04) == .calm, "calm threshold")
        try expect(BurnRateCalculator.level(for: 0.10) == .active, "active threshold")
        try expect(BurnRateCalculator.level(for: 0.20) == .fast, "fast threshold")
    }

    private static func testBurnRateResetGuard() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let samples = [
            QuotaUsageSample(timestamp: now.addingTimeInterval(-10 * 60), bucketId: "codex", windowKind: .primary, usedPercent: 80),
            QuotaUsageSample(timestamp: now, bucketId: "codex", windowKind: .primary, usedPercent: 2)
        ]
        let result = BurnRateCalculator.calculate(samples: samples, now: now)
        try expect(result.percentPerMinute == nil, "reset must not become negative burn")
        try expect(result.level == .calm, "unknown reset rate uses calm visuals")
    }

    private static func testLocalTokenCumulativeCounters() throws {
        let calendar = utcCalendar()
        let now = date("2026-09-23T12:00:00Z")
        let start = calendar.startOfDay(for: now)
        var accumulator = LocalTokenUsageAccumulator()
        for total in [100_000, 180_000, 250_000] {
            accumulator.record(
                RolloutTokenUsageEvent(timestamp: now, totalTokens: Int64(total)),
                sessionID: "session",
                sessionStartedAt: start,
                now: now,
                calendar: calendar
            )
        }
        try expect(accumulator.snapshot(now: now, calendar: calendar).todayTotalTokens == 250_000, "cumulative samples must count only today's current total")
    }

    private static func testTodaySessionInitialCounter() throws {
        let calendar = utcCalendar()
        let now = date("2026-09-23T12:00:00Z")
        var accumulator = LocalTokenUsageAccumulator()
        accumulator.record(
            RolloutTokenUsageEvent(timestamp: now, totalTokens: 120_000),
            sessionID: "new-session",
            sessionStartedAt: now.addingTimeInterval(-60),
            now: now,
            calendar: calendar
        )
        try expect(accumulator.snapshot(now: now, calendar: calendar).todayTotalTokens == 120_000, "today's first cumulative value is today's usage")
    }

    private static func testLocalTokenMidnightBoundary() throws {
        let calendar = utcCalendar()
        let beforeMidnight = date("2026-09-22T23:59:00Z")
        let afterMidnight = date("2026-09-23T00:05:00Z")
        let sessionStart = date("2026-09-22T16:00:00Z")
        var accumulator = LocalTokenUsageAccumulator()
        accumulator.record(
            RolloutTokenUsageEvent(timestamp: beforeMidnight, totalTokens: 1_200_000),
            sessionID: "overnight",
            sessionStartedAt: sessionStart,
            now: afterMidnight,
            calendar: calendar
        )
        accumulator.record(
            RolloutTokenUsageEvent(timestamp: afterMidnight, totalTokens: 1_400_000),
            sessionID: "overnight",
            sessionStartedAt: sessionStart,
            now: afterMidnight,
            calendar: calendar
        )
        try expect(accumulator.snapshot(now: afterMidnight, calendar: calendar).todayTotalTokens == 200_000, "only the post-midnight delta should count today")
    }

    private static func testLocalTokenMultipleSessions() throws {
        let calendar = utcCalendar()
        let now = date("2026-09-23T12:00:00Z")
        let start = calendar.startOfDay(for: now)
        var accumulator = LocalTokenUsageAccumulator()
        for (id, total) in [("one", Int64(120)), ("two", Int64(340))] {
            accumulator.record(
                RolloutTokenUsageEvent(timestamp: now, totalTokens: total),
                sessionID: id,
                sessionStartedAt: start,
                now: now,
                calendar: calendar
            )
        }
        try expect(accumulator.snapshot(now: now, calendar: calendar).todayTotalTokens == 460, "independent sessions should add their daily totals")
    }

    private static func testMalformedTokenEvent() throws {
        try expect(RolloutTokenParser.parse(line: Data("{broken".utf8)) == nil, "malformed JSON must be ignored")
    }

    private static func testIncompleteRolloutLine() throws {
        let line = Data(#"{"timestamp":"2026-09-23T12:00:00Z","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":120}}}}"#.utf8)
        var buffer = JSONLLineBuffer()
        try expect(buffer.append(line).isEmpty, "unfinished JSONL line must remain buffered")
        let completed = buffer.append(Data([0x0A]))
        try expect(completed.count == 1, "newline should release one complete line")
        try expect(RolloutTokenParser.parse(line: completed[0])?.totalTokens == 120, "completed line should parse once")
    }

    private static func testTokenEventUnknownFields() throws {
        let line = Data("""
        { "timestamp": "2026-09-23T12:00:00Z", "other": { "ignored": true }, "payload": {
          "type": "token_count", "unknown": "ignored", "info": { "total_token_usage": {
            "total_tokens": 1000, "input_tokens": 700, "cached_input_tokens": 500, "output_tokens": 300, "future": 4
          } }
        } }
        """.utf8)
        let event = RolloutTokenParser.parse(line: line)
        try expect(event?.totalTokens == 1000, "unknown fields should not change total")
        try expect(event?.cachedInputTokens == 500, "cached input should remain a separate breakdown")
    }

    private static func testRecentTokenActivity() throws {
        let calendar = utcCalendar()
        let now = date("2026-09-23T12:00:00Z")
        var accumulator = LocalTokenUsageAccumulator()
        accumulator.record(
            RolloutTokenUsageEvent(timestamp: now.addingTimeInterval(-60), totalTokens: 200_000),
            sessionID: "active",
            sessionStartedAt: now,
            now: now,
            calendar: calendar
        )
        let snapshot = accumulator.snapshot(now: now, calendar: calendar)
        try expect(snapshot.recentTokensPerMinute == 100_000, "two-minute rolling rate is recent positive tokens divided by two")
        try expect(snapshot.activityLevel == .fast, "100K tokens/minute enters fast")
    }

    private static func testIdleTokenActivity() throws {
        let calendar = utcCalendar()
        let now = date("2026-09-23T12:00:00Z")
        var accumulator = LocalTokenUsageAccumulator()
        accumulator.record(
            RolloutTokenUsageEvent(timestamp: now.addingTimeInterval(-91), totalTokens: 1_000),
            sessionID: "idle",
            sessionStartedAt: now,
            now: now,
            calendar: calendar
        )
        let snapshot = accumulator.snapshot(now: now, calendar: calendar)
        try expect(snapshot.activityLevel == .calm, "no token delta within 90 seconds must be calm")
        try expect(TokenActivityPolicy.level(tokensPerMinute: 500_000, hasRecentUsage: false) == .calm, "idle policy overrides a stale rolling rate")
    }

    private static func testUnavailableTokensDoNotAffectQuota() throws {
        let unavailable = LocalTokenUsageSnapshot.unavailable(at: date("2026-09-23T12:00:00Z"))
        try expect(!unavailable.isAvailable && unavailable.activityLevel == .calm, "missing local history should render unavailable and calm")
        let quotaJSON = try decodeJSON("""
        { "rateLimits": { "primary": { "usedPercent": 25, "windowDurationMins": 300 } } }
        """)
        try expect(RateLimitParser.parseDetailed(result: quotaJSON).buckets.first?.windows.first?.remainingPercent == 75, "quota parsing remains independent of local-token availability")
    }

    private static func testLocalTokenFormatting() throws {
        let examples: [(Int64, String)] = [
            (523, "523"), (1_240, "1.2K"), (52_300, "52.3K"),
            (1_240_000, "1.24M"), (18_630_000, "18.6M")
        ]
        for (value, expected) in examples {
            try expect(LocalTokenUsageFormatter.format(value) == expected, "unexpected format for \(value)")
        }
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

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func date(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }
}

private struct TestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
