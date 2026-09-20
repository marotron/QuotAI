import XCTest
@testable import QuotAICore

final class PaceCalculatorTests: XCTestCase {
    func testOnPaceAtHalfway() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 10 * 86_400)
        let now = Date(timeIntervalSince1970: 5 * 86_400)
        let result = PaceCalculator.pace(percentUsed: 50, periodStart: start, periodEnd: end, now: now)
        XCTAssertEqual(result.ratio!, 1.0, accuracy: 0.01)
        XCTAssertTrue(result.label.hasPrefix("On pace"))
        XCTAssertFalse(result.isEarly)
    }

    func testOverPace() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 10 * 86_400)
        let now = Date(timeIntervalSince1970: 5 * 86_400)
        let result = PaceCalculator.pace(percentUsed: 80, periodStart: start, periodEnd: end, now: now)
        XCTAssertGreaterThan(result.ratio!, PaceCalculator.greenHi)
        XCTAssertTrue(result.label.hasPrefix("Over"))
    }

    func testExhausted() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 10 * 86_400)
        let result = PaceCalculator.pace(percentUsed: 100, periodStart: start, periodEnd: end, now: start)
        XCTAssertEqual(result.label, "Exhausted")
    }

    func testEarlyDepletionUsesHoursWhenUnderOneDay() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 10 * 86_400)
        let now = Date(timeIntervalSince1970: 1 * 86_400)
        // 90% used after 1 day → ~0.11d to exhaust → hours in label
        let result = PaceCalculator.pace(percentUsed: 90, periodStart: start, periodEnd: end, now: now)
        XCTAssertTrue(result.isEarly)
        XCTAssertTrue(result.label.contains("empties in"), result.label)
        XCTAssertTrue(result.label.contains("h"), result.label)
    }
}
