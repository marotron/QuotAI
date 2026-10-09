import XCTest
@testable import QuotAICore

final class RefreshScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testTwentyFiveHoursUsesHourlyInterval() {
        let end = now.addingTimeInterval(25 * 3600)
        let interval = RefreshSchedule.default.interval(periodEnds: [end], now: now)
        XCTAssertEqual(interval, 3600)
    }

    func testTwentyHoursUsesThirtyMinuteInterval() {
        let end = now.addingTimeInterval(20 * 3600)
        let interval = RefreshSchedule.default.interval(periodEnds: [end], now: now)
        XCTAssertEqual(interval, 1800)
    }

    func testExactlyOneDayStaysHourly() {
        let end = now.addingTimeInterval(24 * 3600)
        let interval = RefreshSchedule.default.interval(periodEnds: [end], now: now)
        XCTAssertEqual(interval, 3600)
    }

    func testFiftyNineMinutesUsesOneMinuteInterval() {
        let end = now.addingTimeInterval(59 * 60)
        let interval = RefreshSchedule.default.interval(periodEnds: [end], now: now)
        XCTAssertEqual(interval, 60)
    }

    func testTwoEndsUsesTheSoonerOne() {
        let sooner = now.addingTimeInterval(59 * 60)
        let later = now.addingTimeInterval(25 * 3600)
        let interval = RefreshSchedule.default.interval(periodEnds: [later, sooner], now: now)
        XCTAssertEqual(interval, 60)
    }

    func testEmptyEndsUsesOtherwiseInterval() {
        let interval = RefreshSchedule.default.interval(periodEnds: [], now: now)
        XCTAssertEqual(interval, 3600)
    }

    func testPastEndUsesOneMinuteInterval() {
        let end = now.addingTimeInterval(-60)
        let interval = RefreshSchedule.default.interval(periodEnds: [end], now: now)
        XCTAssertEqual(interval, 60)

        let due = RefreshSchedule.default.interval(periodEnds: [now], now: now)
        XCTAssertEqual(due, 60)
    }

    func testBadJSONFallsBackToDefault() {
        let decoded = RefreshSchedule.fromStoredJSON(Data("not json".utf8))
        XCTAssertEqual(decoded, .default)
    }

    func testStoredJSONRoundTrip() {
        let custom = RefreshSchedule(
            steps: [RefreshSchedule.Step(underMinutes: 120, everyMinutes: 2)],
            otherwiseMinutes: 45
        )
        let data = try! JSONEncoder().encode(custom)
        XCTAssertEqual(RefreshSchedule.fromStoredJSON(data), custom)
    }

    func testDuplicateThresholdJSONFallsBackToDefault() {
        let json = """
        {"steps":[{"underMinutes":60,"everyMinutes":1},{"underMinutes":60,"everyMinutes":5}],"otherwiseMinutes":60}
        """
        let decoded = RefreshSchedule.fromStoredJSON(Data(json.utf8))
        XCTAssertEqual(decoded, .default)
    }

    func testFittingPicksTheLargestExactUnit() {
        XCTAssertEqual(RefreshDuration.fitting(1), RefreshDuration(count: 1, unit: .minutes))
        XCTAssertEqual(RefreshDuration.fitting(45), RefreshDuration(count: 45, unit: .minutes))
        XCTAssertEqual(RefreshDuration.fitting(60), RefreshDuration(count: 1, unit: .hours))
        XCTAssertEqual(RefreshDuration.fitting(180), RefreshDuration(count: 3, unit: .hours))
        XCTAssertEqual(RefreshDuration.fitting(1_440), RefreshDuration(count: 1, unit: .days))
        XCTAssertEqual(RefreshDuration.fitting(2_880), RefreshDuration(count: 2, unit: .days))
        XCTAssertEqual(RefreshDuration.fitting(0).minutes, 1)
    }

    func testConvertKeepsAnExactSpan() {
        let day = RefreshDuration(count: 1, unit: .days)
        XCTAssertEqual(day.converted(to: .hours), RefreshDuration(count: 24, unit: .hours))
        XCTAssertEqual(day.converted(to: .minutes), RefreshDuration(count: 1_440, unit: .minutes))
        XCTAssertEqual(day.converted(to: .days), day)
    }

    func testConvertRoundsPartialUnitsToAtLeastOne() {
        XCTAssertEqual(
            RefreshDuration(count: 90, unit: .minutes).converted(to: .hours),
            RefreshDuration(count: 2, unit: .hours)
        )
        XCTAssertEqual(
            RefreshDuration(count: 30, unit: .minutes).converted(to: .hours),
            RefreshDuration(count: 1, unit: .hours)
        )
    }

    func testDurationMinutesFollowTheUnit() {
        XCTAssertEqual(RefreshDuration(count: 1, unit: .days).minutes, 1_440)
        XCTAssertEqual(RefreshDuration(count: 3, unit: .hours).minutes, 180)
        XCTAssertEqual(RefreshDuration(count: 0, unit: .hours).minutes, 60)
    }

    func testUnitTitles() {
        XCTAssertEqual(RefreshUnit.hours.title(count: 1), "hr")
        XCTAssertEqual(RefreshUnit.hours.title(count: 3), "hrs")
        XCTAssertEqual(RefreshUnit.days.title(count: 1), "day")
        XCTAssertEqual(RefreshUnit.days.title(count: 2), "days")
        XCTAssertEqual(RefreshUnit.minutes.title(count: 5), "min")
    }

    func testSubMinuteIntervalJSONFallsBackToDefault() {
        let json = """
        {"steps":[{"underMinutes":60,"everyMinutes":0}],"otherwiseMinutes":60}
        """
        let decoded = RefreshSchedule.fromStoredJSON(Data(json.utf8))
        XCTAssertEqual(decoded, .default)
    }
}
