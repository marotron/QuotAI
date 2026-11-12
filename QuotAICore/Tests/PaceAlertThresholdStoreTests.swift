import XCTest
@testable import QuotAICore

final class PaceAlertThresholdStoreTests: XCTestCase {
    func testCursorDefaultsWhenKeysMissing() {
        XCTAssertEqual(PaceAlertThresholdStore.cursor(from: [:]), .default)
    }

    func testGrokDefaultsWhenKeysMissing() {
        XCTAssertEqual(PaceAlertThresholdStore.grok(from: [:]), .grokDefault)
    }

    func testCursorReadsLegacyKeys() {
        let ints: [String: Int] = [
            "overMaxStartPct": 30,
            "overEmptyBeforePct": 98,
            "underAfterPct": 27,
            "underMinEndPct": 90,
            "overCurvePct": 10,
            "underCurvePct": 5
        ]
        let th = PaceAlertThresholdStore.cursor(from: ints)
        XCTAssertEqual(th.overMaxStartPct, 30)
        XCTAssertEqual(th.overEmptyBeforePct, 98)
        XCTAssertEqual(th.underAfterPct, 27)
        XCTAssertEqual(th.underMinEndPct, 90)
        XCTAssertEqual(th.overCurvePct, 10)
        XCTAssertEqual(th.underCurvePct, 5)
    }

    func testGrokReadsNamespacedKeys() {
        let ints: [String: Int] = [
            "grokOverMaxStartPct": 40,
            "grokOverEmptyBeforePct": 80,
            "grokUnderAfterPct": 45,
            "grokUnderMinEndPct": 88,
            "grokOverCurvePct": 15,
            "grokUnderCurvePct": 12
        ]
        let th = PaceAlertThresholdStore.grok(from: ints)
        XCTAssertEqual(th.overMaxStartPct, 40)
        XCTAssertEqual(th.overEmptyBeforePct, 80)
        XCTAssertEqual(th.underAfterPct, 45)
        XCTAssertEqual(th.underMinEndPct, 88)
        XCTAssertEqual(th.overCurvePct, 15)
        XCTAssertEqual(th.underCurvePct, 12)
    }

    func testGrokKeysDoNotCollideWithCursorLegacy() {
        let ints: [String: Int] = [
            "overMaxStartPct": 25,
            "grokOverMaxStartPct": 40
        ]
        XCTAssertEqual(PaceAlertThresholdStore.cursor(from: ints).overMaxStartPct, 25)
        XCTAssertEqual(PaceAlertThresholdStore.grok(from: ints).overMaxStartPct, 40)
    }
}
