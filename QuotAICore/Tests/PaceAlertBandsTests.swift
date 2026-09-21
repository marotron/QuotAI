import XCTest
@testable import QuotAICore

final class PaceAlertBandsTests: XCTestCase {
    /// Locked Gate 0 defaults: 25 / 95 / 25 / 95.
    private let thresholds = PaceAlertThresholds.default

    func testEvenPaceIsQuiet() {
        let kind = PaceAlertBands.evaluate(
            percentUsed: 50,
            elapsedFraction: 0.50,
            thresholds: thresholds,
            smart: true
        )
        XCTAssertEqual(kind, .quiet)
        XCTAssertFalse(PaceAlertBands.isSignificant(kind: kind))
    }

    func testEarlyUnderIsQuietBeforeUnderAlertsAfter() {
        // t=10% < underAfter 25% → no under alert even with almost no usage.
        let kind = PaceAlertBands.evaluate(
            percentUsed: 2,
            elapsedFraction: 0.10,
            thresholds: thresholds,
            smart: true
        )
        XCTAssertEqual(kind, .quiet)
    }

    func testLateUnderAlerts() {
        // t=80%, u=40% → below under line (u_under≈69.7%).
        let kind = PaceAlertBands.evaluate(
            percentUsed: 40,
            elapsedFraction: 0.80,
            thresholds: thresholds,
            smart: true
        )
        XCTAssertEqual(kind, .under)
        XCTAssertTrue(PaceAlertBands.isSignificant(kind: kind))
    }

    func testOverAlertsAboveOverLine() {
        // t=10%, u=50% → above over line (u_over≈32.9%).
        let kind = PaceAlertBands.evaluate(
            percentUsed: 50,
            elapsedFraction: 0.10,
            thresholds: thresholds,
            smart: true
        )
        XCTAssertEqual(kind, .over)
    }

    func testExhaustedAlwaysSignificant() {
        let kind = PaceAlertBands.evaluate(
            percentUsed: 100,
            elapsedFraction: 0.20,
            thresholds: thresholds,
            smart: true
        )
        XCTAssertEqual(kind, .exhausted)
        XCTAssertTrue(PaceAlertBands.isSignificant(kind: kind))
    }

    func testLegacyUsesRatioThresholdsWhenSmartOff() {
        // r = 0.40/0.80 = 0.50 → under legacy 0.75.
        let under = PaceAlertBands.evaluate(
            percentUsed: 40,
            elapsedFraction: 0.80,
            thresholds: thresholds,
            smart: false,
            legacyUnder: 0.75,
            legacyOver: 1.30
        )
        XCTAssertEqual(under, .under)

        // Mild r=1.20 is quiet under wide legacy band.
        let quiet = PaceAlertBands.evaluate(
            percentUsed: 60,
            elapsedFraction: 0.50,
            thresholds: thresholds,
            smart: false,
            legacyUnder: 0.75,
            legacyOver: 1.30
        )
        XCTAssertEqual(quiet, .quiet)
    }

    func testLineSamplesMatchLockedFormula() {
        // u_over(0.5) = 0.25 + (0.75/0.95)*0.5
        let over = PaceAlertBands.overUsed(atElapsed: 0.5, thresholds: thresholds)
        XCTAssertEqual(over, 0.25 + (0.75 / 0.95) * 0.5, accuracy: 1e-9)

        // u_under(0.8) = (0.95/0.75)*(0.8-0.25)
        let under = PaceAlertBands.underUsed(atElapsed: 0.8, thresholds: thresholds)
        XCTAssertEqual(under, (0.95 / 0.75) * (0.8 - 0.25), accuracy: 1e-9)
    }
}
