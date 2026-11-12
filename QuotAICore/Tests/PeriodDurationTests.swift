import XCTest
@testable import QuotAICore

final class PeriodDurationTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testLengthRequiresPositiveWindow() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertNil(PeriodDuration.length(periodStart: nil, periodEnd: start))
        XCTAssertNil(PeriodDuration.length(periodStart: start, periodEnd: start))
        let length = PeriodDuration.length(
            periodStart: start,
            periodEnd: start.addingTimeInterval(3 * day)
        )
        XCTAssertEqual(length ?? -1, 3 * day, accuracy: 0.001)
    }

    func testBadgeLabelUsesWholeOrOneDecimalDays() {
        XCTAssertEqual(PeriodDuration.badgeLabel(seconds: 31 * day), "31 days")
        XCTAssertEqual(PeriodDuration.badgeLabel(seconds: 3.1 * day), "3.1 days")
    }

    func testDialTimelineTipHalfOf31Days() {
        let tip = PeriodDuration.dialTimelineTip(dialPct: 50, periodLength: 31 * day)
        XCTAssertEqual(tip, "15d 12h elapsed · 15d 12h left")
    }

    func testTimeLeftOmitsWhenLengthMissing() {
        XCTAssertNil(PeriodDuration.timeLeftLabel(elapsedFraction: 0.5, periodLength: nil))
        XCTAssertEqual(
            PeriodDuration.timeLeftLabel(elapsedFraction: 0.5, periodLength: 31 * day),
            "15d 12h left"
        )
    }
}
