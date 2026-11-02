import XCTest
@testable import QuotAICore

final class RefreshFreshnessTests: XCTestCase {
    private let cap: TimeInterval = 3600

    func testTint_ageZeroIsGreenEnd() {
        XCTAssertEqual(RefreshFreshness.tint(age: 0, cap: cap), .ramp(0))
    }

    func testTint_ageMidCapIsMidRamp() {
        XCTAssertEqual(RefreshFreshness.tint(age: 1800, cap: cap), .ramp(0.5))
    }

    func testTint_ageAtOrPastCapIsOverdue() {
        XCTAssertEqual(RefreshFreshness.tint(age: 3600, cap: cap), .overdue)
        XCTAssertEqual(RefreshFreshness.tint(age: 7200, cap: cap), .overdue)
    }

    func testTint_clampsNegativeAgeToGreen() {
        XCTAssertEqual(RefreshFreshness.tint(age: -10, cap: cap), .ramp(0))
    }

    func testElapsedFraction_justRefreshedIsZero() {
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 0, interval: 600), 0)
    }

    func testElapsedFraction_atIntervalIsOne() {
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 600, interval: 600), 1)
    }

    func testElapsedFraction_halfWay() {
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 300, interval: 600), 0.5)
    }

    func testElapsedFraction_pastIntervalClampsToOne() {
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 900, interval: 600), 1)
    }

    func testElapsedFraction_nonPositiveIntervalIsOne() {
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 0, interval: 0), 1)
        XCTAssertEqual(RefreshFreshness.elapsedFraction(age: 10, interval: -5), 1)
    }
}
