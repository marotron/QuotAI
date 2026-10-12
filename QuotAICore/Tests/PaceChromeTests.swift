import XCTest
@testable import QuotAICore

final class PaceChromeTests: XCTestCase {
    private let lo = 0.85
    private let hi = 1.15

    /// on-pace band via ratio; smart via explicit kind (blink always enabled in matrix).
    private func chrome(ratio: Double, smart: PaceAlertKind) -> PaceChrome {
        let pace = PaceResult(ratio: ratio, label: "", isEarly: false, daysToExhaustion: nil)
        return PaceChromeResolver.resolve(
            pace: pace,
            smartKind: smart,
            onPaceLo: lo,
            onPaceHi: hi,
            blinkEnabled: true
        )
    }

    func testScenario1_onPaceUnder_smartQuiet_blueSolid() {
        // r < 85% → under; smart quiet → blue, no blink
        let c = chrome(ratio: 0.70, smart: .quiet)
        XCTAssertEqual(c.tint, .under)
        XCTAssertFalse(c.blink)
    }

    func testScenario2_onPaceOver_smartOver_orangeBlink() {
        let c = chrome(ratio: 1.30, smart: .over)
        XCTAssertEqual(c.tint, .warning)
        XCTAssertTrue(c.blink)
    }

    func testScenario3_onPaceNormal_smartUnder_blueBlink() {
        // Other-like ~0.896 inside 85–115%, smart under corridor
        let c = chrome(ratio: 0.896, smart: .under)
        XCTAssertEqual(c.tint, .under)
        XCTAssertTrue(c.blink)
    }

    func testScenario4_onPaceNormal_smartQuiet_greenSolid() {
        let c = chrome(ratio: 1.0, smart: .quiet)
        XCTAssertEqual(c.tint, .ok)
        XCTAssertFalse(c.blink)
    }

    func testScenario5_onPaceOver_smartUnder_smartWins_blueBlink() {
        let c = chrome(ratio: 1.30, smart: .under)
        XCTAssertEqual(c.tint, .under)
        XCTAssertTrue(c.blink)
    }

    func testScenario6_onPaceUnder_smartOver_smartWins_orangeBlink() {
        let c = chrome(ratio: 0.70, smart: .over)
        XCTAssertEqual(c.tint, .warning)
        XCTAssertTrue(c.blink)
    }

    func testScenario7_onPaceNormal_smartOver_orangeBlink() {
        let c = chrome(ratio: 1.0, smart: .over)
        XCTAssertEqual(c.tint, .warning)
        XCTAssertTrue(c.blink)
    }

    func testScenario8_onPaceOver_smartQuiet_orangeSolid() {
        let c = chrome(ratio: 1.30, smart: .quiet)
        XCTAssertEqual(c.tint, .warning)
        XCTAssertFalse(c.blink)
    }

    func testBlinkDisabledKeepsTint() {
        let pace = PaceResult(ratio: 0.896, label: "", isEarly: false, daysToExhaustion: nil)
        let c = PaceChromeResolver.resolve(
            pace: pace,
            smartKind: .under,
            onPaceLo: lo,
            onPaceHi: hi,
            blinkEnabled: false
        )
        XCTAssertEqual(c.tint, .under)
        XCTAssertFalse(c.blink)
    }
}
