import XCTest
@testable import QuotAICore

final class RemainingTimeTests: XCTestCase {
    func testFullDays() {
        XCTAssertEqual(RemainingTime.format(seconds: 2 * 86_400), "2d")
        XCTAssertEqual(RemainingTime.format(seconds: 86_400), "1d")
    }

    func testUnderOneDayUsesHours() {
        XCTAssertEqual(RemainingTime.format(seconds: 86_399), "24h")
        XCTAssertEqual(RemainingTime.format(seconds: 5 * 3_600), "5h")
        XCTAssertEqual(RemainingTime.format(seconds: 3_600), "1h")
    }

    func testUnderOneHourUsesMinutes() {
        XCTAssertEqual(RemainingTime.format(seconds: 3_599), "60m")
        XCTAssertEqual(RemainingTime.format(seconds: 15 * 60), "15m")
        XCTAssertEqual(RemainingTime.format(seconds: 1), "1m")
        XCTAssertEqual(RemainingTime.format(seconds: 0), "0m")
    }

    func testDaysHelper() {
        XCTAssertEqual(RemainingTime.format(days: 3), "3d")
        XCTAssertEqual(RemainingTime.format(days: 0.5), "12h")
    }

    func testDetailedCombinesUnits() {
        XCTAssertEqual(RemainingTime.formatDetailed(seconds: 29 * 86_400 + 14 * 3_600), "29d 14h")
        XCTAssertEqual(RemainingTime.formatDetailed(seconds: 5 * 86_400), "5d")
        XCTAssertEqual(RemainingTime.formatDetailed(seconds: 5 * 3_600 + 12 * 60), "5h 12m")
        XCTAssertEqual(RemainingTime.formatDetailed(seconds: 4 * 60), "4m")
        XCTAssertEqual(RemainingTime.formatDetailed(seconds: 0), "0m")
    }
}
