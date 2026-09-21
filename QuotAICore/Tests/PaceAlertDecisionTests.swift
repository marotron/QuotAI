import XCTest
@testable import QuotAICore

final class PaceAlertDecisionTests: XCTestCase {
    private let thresholds = PaceAlertThresholds.default

    func testQuietMetersProduceNoChannels() {
        let meters = [
            PaceAlertMeterInput(id: "cursor", name: "Cursor Models", percentUsed: 50, elapsedFraction: 0.50)
        ]
        let result = PaceAlertDecision.evaluate(
            meters: meters,
            thresholds: thresholds,
            smart: true,
            channels: PaceAlertChannels(blink: true, notify: true, email: true)
        )
        XCTAssertFalse(result.shouldBlink)
        XCTAssertFalse(result.shouldNotify)
        XCTAssertFalse(result.shouldEmail)
        XCTAssertEqual(result.signature, "")
    }

    func testSignificantRespectsChannelFlags() {
        // Late under → significant.
        let meters = [
            PaceAlertMeterInput(id: "cursor", name: "Cursor Models", percentUsed: 40, elapsedFraction: 0.80)
        ]
        let allOff = PaceAlertDecision.evaluate(
            meters: meters,
            thresholds: thresholds,
            smart: true,
            channels: PaceAlertChannels(blink: false, notify: false, email: false)
        )
        XCTAssertFalse(allOff.shouldBlink)
        XCTAssertFalse(allOff.shouldNotify)
        XCTAssertFalse(allOff.shouldEmail)
        XCTAssertFalse(allOff.signature.isEmpty)

        let blinkOnly = PaceAlertDecision.evaluate(
            meters: meters,
            thresholds: thresholds,
            smart: true,
            channels: PaceAlertChannels(blink: true, notify: false, email: false)
        )
        XCTAssertTrue(blinkOnly.shouldBlink)
        XCTAssertFalse(blinkOnly.shouldNotify)
        XCTAssertFalse(blinkOnly.shouldEmail)
    }

    func testMultiMeterSignatureIsStableAndSorted() {
        let meters = [
            PaceAlertMeterInput(id: "grok", name: "Grok Bot", percentUsed: 40, elapsedFraction: 0.80),
            PaceAlertMeterInput(id: "cursor", name: "Cursor Models", percentUsed: 50, elapsedFraction: 0.10)
        ]
        let a = PaceAlertDecision.evaluate(
            meters: meters,
            thresholds: thresholds,
            smart: true,
            channels: PaceAlertChannels(blink: true, notify: true, email: true)
        )
        let b = PaceAlertDecision.evaluate(
            meters: meters.reversed(),
            thresholds: thresholds,
            smart: true,
            channels: PaceAlertChannels(blink: true, notify: true, email: true)
        )
        XCTAssertEqual(a.signature, b.signature)
        XCTAssertEqual(a.signature, "cursor:over|grok:under")
        XCTAssertTrue(a.shouldBlink && a.shouldNotify && a.shouldEmail)
    }
}
