import XCTest
@testable import QuotAICore

final class PaceHistorySeriesFilterTests: XCTestCase {
    func testAllShowsEveryMeter() {
        let filter = PaceHistorySeriesFilter.all
        for id in PaceHistoryMeterId.allCases {
            XCTAssertTrue(filter.isVisible(id))
            XCTAssertEqual(filter.avatarCycle(for: id), .all)
        }
    }

    func testSoloShowsOnlyFocus() {
        let filter = PaceHistorySeriesFilter(mode: .solo, focus: .other)
        XCTAssertFalse(filter.isVisible(.cursor))
        XCTAssertTrue(filter.isVisible(.other))
        XCTAssertFalse(filter.isVisible(.grok))
        XCTAssertEqual(filter.avatarCycle(for: .other), .solo)
        XCTAssertEqual(filter.avatarCycle(for: .cursor), .dim)
        XCTAssertEqual(filter.avatarCycle(for: .grok), .dim)
    }

    func testHideHidesOnlyFocus() {
        let filter = PaceHistorySeriesFilter(mode: .hide, focus: .grok)
        XCTAssertTrue(filter.isVisible(.cursor))
        XCTAssertTrue(filter.isVisible(.other))
        XCTAssertFalse(filter.isVisible(.grok))
        XCTAssertEqual(filter.avatarCycle(for: .grok), .hide)
        XCTAssertEqual(filter.avatarCycle(for: .cursor), .all)
    }

    func testCycleAllToSoloToHideToAllOnSameMeter() {
        var filter = PaceHistorySeriesFilter.all
        filter = filter.cycling(tapped: .cursor)
        XCTAssertEqual(filter, PaceHistorySeriesFilter(mode: .solo, focus: .cursor))
        filter = filter.cycling(tapped: .cursor)
        XCTAssertEqual(filter, PaceHistorySeriesFilter(mode: .hide, focus: .cursor))
        filter = filter.cycling(tapped: .cursor)
        XCTAssertEqual(filter, .all)
    }

    func testTappingOtherMeterJumpsToSolo() {
        let soloCursor = PaceHistorySeriesFilter(mode: .solo, focus: .cursor)
        XCTAssertEqual(
            soloCursor.cycling(tapped: .grok),
            PaceHistorySeriesFilter(mode: .solo, focus: .grok)
        )
        let hideOther = PaceHistorySeriesFilter(mode: .hide, focus: .other)
        XCTAssertEqual(
            hideOther.cycling(tapped: .cursor),
            PaceHistorySeriesFilter(mode: .solo, focus: .cursor)
        )
    }
}
