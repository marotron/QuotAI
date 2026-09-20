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

    func testSignificantOutsideWideBand() {
        XCTAssertFalse(PaceCalculator.isSignificant(pace: nil))
        XCTAssertFalse(PaceCalculator.isSignificant(pace: PaceResult(ratio: 1.0, label: "", isEarly: false, daysToExhaustion: nil)))
        // Mild under/over (inside significant band, outside green) → not significant.
        XCTAssertFalse(PaceCalculator.isSignificant(pace: PaceResult(ratio: 0.85, label: "", isEarly: false, daysToExhaustion: nil)))
        XCTAssertFalse(PaceCalculator.isSignificant(pace: PaceResult(ratio: 1.20, label: "", isEarly: false, daysToExhaustion: nil)))
        // Far under / over.
        XCTAssertTrue(PaceCalculator.isSignificant(pace: PaceResult(ratio: 0.70, label: "", isEarly: false, daysToExhaustion: nil)))
        XCTAssertTrue(PaceCalculator.isSignificant(pace: PaceResult(ratio: 1.40, label: "", isEarly: false, daysToExhaustion: nil)))
        XCTAssertTrue(PaceCalculator.isSignificant(pace: PaceResult(ratio: nil, label: "Exhausted", isEarly: false, daysToExhaustion: 0)))
    }

    func testSignificantUsesCustomThresholds() {
        let mildUnder = PaceResult(ratio: 0.85, label: "", isEarly: false, daysToExhaustion: nil)
        let mildOver = PaceResult(ratio: 1.20, label: "", isEarly: false, daysToExhaustion: nil)
        // Tighter band → mild deviations become significant.
        XCTAssertTrue(PaceCalculator.isSignificant(pace: mildUnder, under: 0.90, over: 1.10))
        XCTAssertTrue(PaceCalculator.isSignificant(pace: mildOver, under: 0.90, over: 1.10))
        // Wider band → 0.70 is still inside.
        XCTAssertFalse(PaceCalculator.isSignificant(
            pace: PaceResult(ratio: 0.70, label: "", isEarly: false, daysToExhaustion: nil),
            under: 0.60,
            over: 1.50
        ))
    }

    func testIsOnPaceDeadZone() {
        XCTAssertTrue(PaceCalculator.isOnPace(1.0))
        XCTAssertTrue(PaceCalculator.isOnPace(0.90))
        XCTAssertTrue(PaceCalculator.isOnPace(1.10))
        XCTAssertTrue(PaceCalculator.isOnPace(1.03))
        XCTAssertFalse(PaceCalculator.isOnPace(0.89))
        XCTAssertFalse(PaceCalculator.isOnPace(1.11))
        // Custom tight band.
        XCTAssertFalse(PaceCalculator.isOnPace(1.08, lo: 0.95, hi: 1.05))
        XCTAssertTrue(PaceCalculator.isOnPace(1.08, lo: 0.80, hi: 1.20))
    }
}
