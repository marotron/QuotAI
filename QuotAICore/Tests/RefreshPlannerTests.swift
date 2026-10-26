import XCTest
@testable import QuotAICore

final class RefreshPlannerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let schedule = RefreshSchedule.default

    /// Default schedule: 25h remaining → otherwise 60 min.
    private var farEnd: Date { now.addingTimeInterval(25 * 3600) }
    /// Default schedule: 59 min remaining → every 1 min.
    private var nearEnd: Date { now.addingTimeInterval(59 * 60) }

    func testDynamic_cursorDueWhenAgeMeetsItsInterval() {
        let lastCursor = now.addingTimeInterval(-3600) // 60 min ago
        let lastGrok = now.addingTimeInterval(-60) // 1 min ago
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: lastCursor,
            lastGrok: lastGrok,
            now: now
        )
        XCTAssertEqual(due, [.cursor])
    }

    func testDynamic_grokDueIndependently() {
        let lastCursor = now.addingTimeInterval(-60)
        let lastGrok = now.addingTimeInterval(-3600)
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: lastCursor,
            lastGrok: lastGrok,
            now: now
        )
        XCTAssertEqual(due, [.grok])
    }

    func testDynamic_bothDueWhenBothStale() {
        let stale = now.addingTimeInterval(-3600)
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: stale,
            lastGrok: stale,
            now: now
        )
        XCTAssertEqual(due, [.cursor, .grok])
    }

    func testDynamic_neverFetchedIsDue() {
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: nil,
            lastGrok: nil,
            now: now
        )
        XCTAssertEqual(due, [.cursor, .grok])
    }

    func testDynamic_nearResetUsesShorterIntervalForThatFamily() {
        // Cursor near reset → 1 min interval; refreshed 30s ago → not due.
        // Grok far → 60 min; refreshed 60 min ago → due.
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [nearEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: now.addingTimeInterval(-30),
            lastGrok: now.addingTimeInterval(-3600),
            now: now
        )
        XCTAssertEqual(due, [.grok])
    }

    func testFixed_usesSharedMinutesForBothFamilies() {
        let due = RefreshPlanner.dueFamilies(
            dynamic: false,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [nearEnd],
            grokPeriodEnds: [nearEnd],
            lastCursor: now.addingTimeInterval(-10 * 60),
            lastGrok: now.addingTimeInterval(-60),
            now: now
        )
        XCTAssertEqual(due, [.cursor])
    }

    func testMissingEnds_usesOtherwiseInterval() {
        let due = RefreshPlanner.dueFamilies(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [],
            grokPeriodEnds: [],
            lastCursor: now.addingTimeInterval(-3600),
            lastGrok: now.addingTimeInterval(-60),
            now: now
        )
        XCTAssertEqual(due, [.cursor])
    }

    func testNextFire_isEarliestFamilyDueTime() {
        // Both far → 60 min intervals. Cursor due in 10 min; Grok due in 40 min.
        let fire = RefreshPlanner.nextFire(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: now.addingTimeInterval(-50 * 60),
            lastGrok: now.addingTimeInterval(-20 * 60),
            now: now
        )
        XCTAssertEqual(fire, now.addingTimeInterval(10 * 60))
    }

    func testNextFire_whenAlreadyDue_isNow() {
        let fire = RefreshPlanner.nextFire(
            dynamic: true,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [farEnd],
            grokPeriodEnds: [farEnd],
            lastCursor: now.addingTimeInterval(-3600),
            lastGrok: now.addingTimeInterval(-60),
            now: now
        )
        XCTAssertEqual(fire, now)
    }

    func testNextFire_fixed_usesSharedMinutes() {
        let fire = RefreshPlanner.nextFire(
            dynamic: false,
            fixedMinutes: 15,
            schedule: schedule,
            cursorPeriodEnds: [nearEnd],
            grokPeriodEnds: [nearEnd],
            lastCursor: now.addingTimeInterval(-5 * 60),
            lastGrok: now.addingTimeInterval(-5 * 60),
            now: now
        )
        XCTAssertEqual(fire, now.addingTimeInterval(10 * 60))
    }

    func testNextFire_neverFetched_isNow() {
        let fire = RefreshPlanner.nextFire(
            dynamic: false,
            fixedMinutes: 10,
            schedule: schedule,
            cursorPeriodEnds: [],
            grokPeriodEnds: [],
            lastCursor: nil,
            lastGrok: nil,
            now: now
        )
        XCTAssertEqual(fire, now)
    }
}
