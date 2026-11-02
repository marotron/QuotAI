import XCTest
@testable import QuotAICore

final class PaceMeterPresentationTests: XCTestCase {
    func testPacePercentTextIsNeutralPercentOnly() {
        XCTAssertEqual(PaceMeterPresentation.pacePercentText(ratio: 0.96, exhausted: false), "96%")
        XCTAssertEqual(PaceMeterPresentation.pacePercentText(ratio: 0.38, exhausted: false), "38%")
        XCTAssertEqual(PaceMeterPresentation.pacePercentText(ratio: 1.20, exhausted: false), "120%")
        XCTAssertEqual(PaceMeterPresentation.pacePercentText(ratio: nil, exhausted: false), "—")
        XCTAssertEqual(PaceMeterPresentation.pacePercentText(ratio: 1.0, exhausted: true), "—")
    }

    func testAlertSymbolMapping() {
        XCTAssertEqual(PaceMeterPresentation.alertSymbolName(kind: .quiet), "checkmark.circle")
        XCTAssertEqual(PaceMeterPresentation.alertSymbolName(kind: .under), "arrow.down.circle")
        XCTAssertEqual(PaceMeterPresentation.alertSymbolName(kind: .over), "arrow.up.circle")
        XCTAssertEqual(PaceMeterPresentation.alertSymbolName(kind: .exhausted), "xmark.circle")
    }

    func testAlertTintMapping() {
        XCTAssertEqual(PaceMeterPresentation.alertTint(kind: .quiet), .neutral)
        XCTAssertEqual(PaceMeterPresentation.alertTint(kind: .under), .under)
        XCTAssertEqual(PaceMeterPresentation.alertTint(kind: .over), .warning)
        XCTAssertEqual(PaceMeterPresentation.alertTint(kind: .exhausted), .critical)
    }

    func testSeriesColorsAreFixedHex() {
        XCTAssertEqual(PaceHistorySeriesColor.models.hex, "#8b5cf6")
        XCTAssertEqual(PaceHistorySeriesColor.other.hex, "#d946ef")
        XCTAssertEqual(PaceHistorySeriesColor.grok.hex, "#c084fc")
    }
}
