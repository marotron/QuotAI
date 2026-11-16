import XCTest
@testable import QuotAICore

final class CodexQuotaTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testBlockedNoticeOnlyWhenOrdinaryBlockIsNotAlreadyShownByAnExhaustedWindow() {
        let available = window("primary", used: 99.9, reset: 300)
        let exhausted = window("secondary", used: 100, reset: 300)
        var otherBucket = exhausted
        otherBucket.id = "other.primary"
        XCTAssertFalse(CodexQuotaSnapshot.shouldShowBlockedNotice(allowed: nil, windows: []))
        XCTAssertFalse(CodexQuotaSnapshot.shouldShowBlockedNotice(allowed: true, windows: [exhausted]))
        XCTAssertTrue(CodexQuotaSnapshot.shouldShowBlockedNotice(allowed: false, windows: []))
        XCTAssertTrue(CodexQuotaSnapshot.shouldShowBlockedNotice(allowed: false, windows: [available, otherBucket]))
        XCTAssertFalse(CodexQuotaSnapshot.shouldShowBlockedNotice(allowed: false, windows: [available, exhausted]))
    }

    func testIndependentWindowsAndAdditionalBucketsKeepZeroAndUnknownDistinct() throws {
        let data = Data("""
        {"account_id":"account","rate_limit":{"allowed":false,
          "primary_window":{"used_percent":0,"limit_window_seconds":18000,"reset_at":2000000300},
          "secondary_window":{"used_percent":72,"limit_window_seconds":604800,"reset_at":2000100000}},
         "additional_rate_limits":[{"metered_feature":"another","limit_name":"Another allowance",
          "rate_limit":{"primary_window":{"used_percent":null,"limit_window_seconds":null,"reset_at":null}}}]}
        """.utf8)
        let snapshot = try CodexQuotaSnapshot.parse(data, expectedAccount: "account")
        XCTAssertEqual(snapshot.windows.map(\.id), ["codex.primary", "codex.secondary", "another.primary"])
        XCTAssertEqual(snapshot.windows[0].usedPercent, 0)
        XCTAssertEqual(snapshot.windows[0].durationLabel, "5h")
        XCTAssertEqual(snapshot.windows[1].durationLabel, "7d")
        XCTAssertNil(snapshot.windows[2].usedPercent)
        XCTAssertNil(snapshot.windows[2].resetsAt)
        XCTAssertEqual(snapshot.ordinaryUsageAllowed, false)
    }

    func testWrongAccountAndDuplicateBucketAreRejected() throws {
        XCTAssertThrowsError(try CodexQuotaSnapshot.parse(Data("{\"account_id\":\"other\"}".utf8), expectedAccount: "account"))
        let duplicate = Data("""
        {"rate_limit":{"primary_window":{"used_percent":30}},
         "additional_rate_limits":[{"metered_feature":"codex","rate_limit":{"primary_window":{"used_percent":40}}}]}
        """.utf8)
        XCTAssertThrowsError(try CodexQuotaSnapshot.parse(duplicate, expectedAccount: "account"))
    }

    func testAbsentWindowsAndInvalidReadingsNeverBecomeZeroOrNewPeriods() throws {
        let empty = try CodexQuotaSnapshot.parse(Data("{}".utf8), expectedAccount: "account")
        XCTAssertTrue(empty.windows.isEmpty)
        XCTAssertNil(empty.ordinaryUsageAllowed)
        let invalid = try CodexQuotaSnapshot.parse(Data("""
        {"rate_limit":{"primary_window":{"used_percent":-1,"limit_window_seconds":-300,"reset_at":0},"secondary_window":null}}
        """.utf8), expectedAccount: "account")
        XCTAssertEqual(invalid.windows.count, 1)
        XCTAssertNil(invalid.windows[0].usedPercent)
        XCTAssertNil(invalid.windows[0].duration)
        XCTAssertNil(invalid.windows[0].resetsAt)
    }

    func testWindowRulesShareFastestRateAndStayLatchedThroughCorrections() {
        var state = CodexRefreshState()
        let rules = [
            "codex.primary": CodexRefreshRule(enabled: true, percent: 90, minutes: 5),
            "codex.secondary": CodexRefreshRule(enabled: true, percent: 50, minutes: 1),
        ]
        var windows = [window("primary", used: 95, reset: 600), window("secondary", used: 60, reset: 3600)]
        state.update(windows: windows, rules: rules, fetchedAt: now, now: now)
        XCTAssertEqual(state.activeEnds.count, 2)
        XCTAssertEqual(state.interval(normal: 600, rules: rules, now: now), 60)
        XCTAssertEqual(state.interval(normal: 30, rules: rules, now: now), 30)
        windows[0].usedPercent = 2
        windows[1].usedPercent = 3
        state.update(windows: windows, rules: rules, fetchedAt: now.addingTimeInterval(60), now: now.addingTimeInterval(60))
        XCTAssertEqual(state.activeEnds.count, 2)
        let restored = try? JSONDecoder().decode(CodexRefreshState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(restored?.interval(normal: 600, rules: rules, now: now), 60)
    }

    func testChangedAndExpiredResetsReleaseTriggersIndependently() {
        var state = CodexRefreshState()
        let rules = ["codex.primary": CodexRefreshRule(enabled: true, minutes: 1),
                     "codex.secondary": CodexRefreshRule(enabled: true, minutes: 5)]
        state.update(windows: [window("primary", used: 95, reset: 300), window("secondary", used: 95, reset: 900)],
            rules: rules, fetchedAt: now, now: now)
        state.update(windows: [window("primary", used: 2, reset: 600)], rules: rules, fetchedAt: now, now: now)
        XCTAssertNil(state.activeEnds["codex.primary"])
        XCTAssertEqual(state.interval(normal: 600, rules: rules, now: now), 300)
        XCTAssertEqual(state.interval(normal: 600, rules: rules, now: now.addingTimeInterval(901)), 600)
    }

    func testStaleMissingAndExpiredDataCannotActivateRules() {
        let rules = ["codex.primary": CodexRefreshRule(enabled: true)]
        for (fetched, used, reset) in [(now.addingTimeInterval(-3601), 99.0 as Double?, 300.0 as Double?),
                                       (now, nil, 300), (now, 99, nil), (now, 99, -1)] {
            var state = CodexRefreshState()
            state.update(windows: [window("primary", used: used, reset: reset)], rules: rules, fetchedAt: fetched, now: now)
            XCTAssertTrue(state.activeEnds.isEmpty)
        }
    }

    private func window(_ slot: String, used: Double?, reset: Double?) -> CodexQuotaWindow {
        CodexQuotaWindow(id: "codex.\(slot)", bucketName: "Codex", slot: slot, usedPercent: used,
            duration: 18000, resetsAt: reset.map { now.addingTimeInterval($0) })
    }
}
