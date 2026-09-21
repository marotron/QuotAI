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
        let b = 0.95
        let d = 0.95
        // u_over(0.5) linear; also ≥ parallel floor through Full quota before.
        let over = PaceAlertBands.overUsed(atElapsed: 0.5, thresholds: thresholds)
        let overRaw = 0.25 + (0.75 / 0.95) * 0.5
        XCTAssertEqual(over, max(overRaw, 0.5 + (1 - b)), accuracy: 1e-9)

        // u_under(0.8) linear; also ≤ parallel ceiling through Min usage by period end.
        let under = PaceAlertBands.underUsed(atElapsed: 0.8, thresholds: thresholds)
        let underRaw = (0.95 / 0.75) * (0.8 - 0.25)
        XCTAssertEqual(under, min(underRaw, 0.8 + (d - 1)), accuracy: 1e-9)
    }

    func testOverParabolicUsesPowerTwo() {
        let curved = PaceAlertThresholds(
            overMaxStartPct: 25,
            overEmptyBeforePct: 95,
            underAfterPct: 25,
            underMinEndPct: 95,
            overCurvePct: 100,
            underCurvePct: 0
        )
        let t = 0.5
        let a = 0.25
        let b = 0.95
        let raw = a + (1 - a) * pow(t / b, 2)
        let over = PaceAlertBands.overUsed(atElapsed: t, thresholds: curved)
        XCTAssertEqual(over, max(raw, t + (1 - b)), accuracy: 1e-9)
    }

    func testUnderParabolicMirrorsWithReciprocalPower() {
        let curved = PaceAlertThresholds(
            overMaxStartPct: 25,
            overEmptyBeforePct: 95,
            underAfterPct: 25,
            underMinEndPct: 95,
            overCurvePct: 0,
            underCurvePct: 100
        )
        let t = 0.8
        let c = 0.25
        let d = 0.95
        let s = (t - c) / (1 - c)
        let raw = d * pow(s, 0.5)
        let under = PaceAlertBands.underUsed(atElapsed: t, thresholds: curved)
        XCTAssertEqual(under, min(raw, t + (d - 1)), accuracy: 1e-9)
    }

    func testSymmetricEndpointsMirrorAcrossEvenPace() {
        // Over (0, A)→(B, 1) with s^p; under (A, 0)→(1, B) with s^(1/p)
        // is the reflection of over across u = t (before parallel clamps).
        let A = 40.0
        let B = 90.0
        let p = 2.0
        let th = PaceAlertThresholds(
            overMaxStartPct: A,
            overEmptyBeforePct: B,
            underAfterPct: A,
            underMinEndPct: B,
            overCurvePct: 100,
            underCurvePct: 100
        )
        let s = 0.4
        let tOver = (B / 100) * s
        let uOverRaw = (A / 100) + (1 - A / 100) * pow(s, p)
        let tUnder = uOverRaw
        let uUnderExpected = tOver
        let under = PaceAlertBands.underUsed(atElapsed: tUnder, thresholds: th)
        XCTAssertEqual(under, min(uUnderExpected, tUnder + (B / 100 - 1)), accuracy: 1e-9)
        let over = PaceAlertBands.overUsed(atElapsed: tOver, thresholds: th)
        XCTAssertEqual(over, max(uOverRaw, tOver + (1 - B / 100)), accuracy: 1e-9)
    }

    func testOverNeverBelowParallelThroughFullQuotaBefore() {
        // Full curve would dip below the floor without the clamp.
        let th = PaceAlertThresholds(
            overMaxStartPct: 25,
            overEmptyBeforePct: 95,
            underAfterPct: 25,
            underMinEndPct: 95,
            overCurvePct: 100,
            underCurvePct: 0
        )
        let t = 0.5
        let floor = PaceAlertBands.overFloor(atElapsed: t, thresholds: th)
        let over = PaceAlertBands.overUsed(atElapsed: t, thresholds: th)
        XCTAssertGreaterThanOrEqual(over, floor - 1e-12)
        // Floor is above even pace when empty-before < 100%.
        XCTAssertGreaterThan(floor, t)
        XCTAssertEqual(over, floor, accuracy: 1e-9)
    }

    func testUnderNeverAboveParallelThroughMinEnd() {
        let th = PaceAlertThresholds(
            overMaxStartPct: 25,
            overEmptyBeforePct: 95,
            underAfterPct: 1,
            underMinEndPct: 95,
            overCurvePct: 0,
            underCurvePct: 100
        )
        let t = 0.5
        let ceiling = PaceAlertBands.underCeiling(atElapsed: t, thresholds: th)
        let under = PaceAlertBands.underUsed(atElapsed: t, thresholds: th)
        XCTAssertLessThanOrEqual(under, ceiling + 1e-12)
        // Ceiling is below even pace when min-end < 100%.
        XCTAssertLessThan(ceiling, t)
        XCTAssertEqual(under, ceiling, accuracy: 1e-9)
    }
}
