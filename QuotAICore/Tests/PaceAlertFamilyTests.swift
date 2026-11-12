import XCTest
@testable import QuotAICore

final class PaceAlertFamilyTests: XCTestCase {
    func testResolveMapsMeterIds() {
        XCTAssertEqual(PaceAlertFamily.resolve(meterId: "cursor"), .cursor)
        XCTAssertEqual(PaceAlertFamily.resolve(meterId: "other"), .cursor)
        XCTAssertEqual(PaceAlertFamily.resolve(meterId: "grok"), .grok)
    }

    func testResolveMapsMeterNames() {
        XCTAssertEqual(PaceAlertFamily.resolve(meterName: "Cursor Models"), .cursor)
        XCTAssertEqual(PaceAlertFamily.resolve(meterName: "Other Models"), .cursor)
        XCTAssertEqual(PaceAlertFamily.resolve(meterName: "Grok Bot"), .grok)
    }

    func testThresholdsPicksProfilePerMeter() {
        let cursor = PaceAlertThresholds.default
        let grok = PaceAlertThresholds.grokDefault
        XCTAssertEqual(
            PaceAlertFamily.thresholds(forMeterId: "other", cursor: cursor, grok: grok),
            cursor
        )
        XCTAssertEqual(
            PaceAlertFamily.thresholds(forMeterId: "grok", cursor: cursor, grok: grok),
            grok
        )
    }
}
