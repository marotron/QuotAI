import XCTest
@testable import QuotAICore

final class AutomaticRefreshPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: hour, minute: minute))!
    }

    func testQuietWindowAcrossMidnightAndBoundaries() {
        XCTAssertTrue(AutomaticRefreshPolicy.isQuiet(now: date(22), enabled: true, startMinute: 1320, endMinute: 420, calendar: calendar))
        XCTAssertTrue(AutomaticRefreshPolicy.isQuiet(now: date(6, 59), enabled: true, startMinute: 1320, endMinute: 420, calendar: calendar))
        XCTAssertFalse(AutomaticRefreshPolicy.isQuiet(now: date(7), enabled: true, startMinute: 1320, endMinute: 420, calendar: calendar))
        XCTAssertFalse(AutomaticRefreshPolicy.isQuiet(now: date(23), enabled: false, startMinute: 1320, endMinute: 420, calendar: calendar))
        XCTAssertFalse(AutomaticRefreshPolicy.isQuiet(now: date(12), enabled: true, startMinute: 720, endMinute: 720, calendar: calendar))
        XCTAssertTrue(AutomaticRefreshPolicy.isQuiet(now: date(12), enabled: true, startMinute: 600, endMinute: 780, calendar: calendar))
    }

    func testThresholdRequiresAvailableReadingAndFutureReset() {
        let now = date(12)
        let end = date(13)
        XCTAssertEqual(AutomaticRefreshPolicy.thresholdEnd(meter: QuotaMeter(name: "test", percentUsed: 90, periodEnd: end), threshold: 90, now: now), end)
        XCTAssertNil(AutomaticRefreshPolicy.thresholdEnd(meter: QuotaMeter(name: "test", percentUsed: 89, periodEnd: end), threshold: 90, now: now))
        XCTAssertNil(AutomaticRefreshPolicy.thresholdEnd(meter: QuotaMeter(name: "test", percentUsed: 90), threshold: 90, now: now))
        XCTAssertNil(AutomaticRefreshPolicy.thresholdEnd(meter: QuotaMeter(name: "test", percentUsed: 90, isUnavailable: true, periodEnd: end), threshold: 90, now: now))
        XCTAssertNil(AutomaticRefreshPolicy.thresholdEnd(meter: QuotaMeter(name: "test", percentUsed: 90, periodEnd: now), threshold: 90, now: now))
    }

    func testThresholdOverrideOnlyMakesAffectedFamilyFaster() {
        let now = date(12)
        let last = now.addingTimeInterval(-120)
        let due = RefreshPlanner.dueFamilies(dynamic: false, fixedMinutes: 10, schedule: .default,
                                              cursorPeriodEnds: [], grokPeriodEnds: [], lastCursor: last,
                                              lastGrok: last, now: now, cursorOverride: 60)
        XCTAssertEqual(due, [.cursor])
    }

    func testFastestRefreshWinsRegardlessOfWhichRuleRequestsIt() {
        let now = date(12)
        // A slower usage rule must never override a faster Dynamic cadence, or vice versa.
        for (dynamicMinutes, usageMinutes) in [(1, 5), (5, 1)] {
            let schedule = RefreshSchedule(
                steps: [.init(underMinutes: 60, everyMinutes: dynamicMinutes)],
                otherwiseMinutes: 30
            )
            let end = now.addingTimeInterval(30 * 60)
            let usageInterval = TimeInterval(usageMinutes * 60)
            let last = now.addingTimeInterval(-30)
            XCTAssertEqual(RefreshPlanner.nextFire(
                dynamic: true, fixedMinutes: 10, schedule: schedule,
                cursorPeriodEnds: [end], grokPeriodEnds: [end],
                lastCursor: last, lastGrok: last, now: now,
                cursorOverride: usageInterval, grokOverride: usageInterval
            ), last.addingTimeInterval(60))
            XCTAssertEqual(RefreshPlanner.dueFamilies(
                dynamic: true, fixedMinutes: 10, schedule: schedule,
                cursorPeriodEnds: [end], grokPeriodEnds: [end],
                lastCursor: now.addingTimeInterval(-60), lastGrok: now.addingTimeInterval(-60),
                now: now, cursorOverride: usageInterval, grokOverride: usageInterval
            ), [.cursor, .grok])
        }
    }

    func testDynamicAccelerationWinsWhileSlowerUsageRuleRemainsActive() {
        let last = date(12)
        let end = date(13, 1)
        XCTAssertEqual(RefreshPlanner.nextFire(
            dynamic: true, fixedMinutes: 10, schedule: .default,
            cursorPeriodEnds: [end], grokPeriodEnds: [end],
            lastCursor: last, lastGrok: last, now: last,
            cursorOverride: 300, grokOverride: 300
        ), last.addingTimeInterval(300))
        let now = last.addingTimeInterval(120)
        XCTAssertEqual(RefreshPlanner.dueFamilies(
            dynamic: true, fixedMinutes: 10, schedule: .default,
            cursorPeriodEnds: [end], grokPeriodEnds: [end],
            lastCursor: last, lastGrok: last, now: now,
            cursorOverride: 300, grokOverride: 300
        ), [.cursor, .grok])
    }

    func testSlowerUsageRuleCannotSlowFixedPolling() {
        let now = date(12)
        XCTAssertEqual(RefreshPlanner.dueFamilies(
            dynamic: false, fixedMinutes: 5, schedule: .default,
            cursorPeriodEnds: [], grokPeriodEnds: [],
            lastCursor: now.addingTimeInterval(-300), lastGrok: now.addingTimeInterval(-300),
            now: now, cursorOverride: 600, grokOverride: 600
        ), [.cursor, .grok])
    }

}
