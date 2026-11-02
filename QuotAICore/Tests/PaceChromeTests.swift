import XCTest
@testable import QuotAICore

final class PaceChromeTests: XCTestCase {
    /// Corridor-only chrome: tint from kind; quiet / alerts-off → neutral; blink only significant.
    private func chrome(
        kind: PaceAlertKind,
        alertsEnabled: Bool = true,
        blinkEnabled: Bool = true
    ) -> PaceChrome {
        PaceChromeResolver.resolve(
            corridorKind: kind,
            corridorAlertsEnabled: alertsEnabled,
            blinkEnabled: blinkEnabled
        )
    }

    func testQuietIsNeutralSolid() {
        let c = chrome(kind: .quiet)
        XCTAssertEqual(c.tint, .neutral)
        XCTAssertFalse(c.blink)
    }

    func testUnderIsBlueBlink() {
        let c = chrome(kind: .under)
        XCTAssertEqual(c.tint, .under)
        XCTAssertTrue(c.blink)
    }

    func testOverIsOrangeBlink() {
        let c = chrome(kind: .over)
        XCTAssertEqual(c.tint, .warning)
        XCTAssertTrue(c.blink)
    }

    func testExhaustedIsRedBlink() {
        let c = chrome(kind: .exhausted)
        XCTAssertEqual(c.tint, .critical)
        XCTAssertTrue(c.blink)
    }

    func testAlertsOffAlwaysNeutralNoBlink() {
        for kind: PaceAlertKind in [.quiet, .under, .over, .exhausted] {
            let c = chrome(kind: kind, alertsEnabled: false, blinkEnabled: true)
            XCTAssertEqual(c.tint, .neutral, "alerts off → neutral for \(kind)")
            XCTAssertFalse(c.blink, "alerts off → no blink for \(kind)")
        }
    }

    func testBlinkDisabledKeepsTint() {
        let c = chrome(kind: .under, blinkEnabled: false)
        XCTAssertEqual(c.tint, .under)
        XCTAssertFalse(c.blink)
    }

    func testQuietNeverBlinksEvenWhenBlinkEnabled() {
        let c = chrome(kind: .quiet, blinkEnabled: true)
        XCTAssertFalse(c.blink)
    }
}
