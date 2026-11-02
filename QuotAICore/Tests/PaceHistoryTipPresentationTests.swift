import XCTest
@testable import QuotAICore

final class PaceHistoryTipPresentationTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testBillingFamilyGroupsCursorOtherVsGrok() {
        XCTAssertEqual(PaceHistoryTipPresentation.billingFamily(for: .cursor), .cursor)
        XCTAssertEqual(PaceHistoryTipPresentation.billingFamily(for: .other), .cursor)
        XCTAssertEqual(PaceHistoryTipPresentation.billingFamily(for: .grok), .grok)
    }

    func testPeriodAnchorFromLatestSample() {
        let samples = [
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 20,
                elapsedPct: 50,
                timestamp: start.addingTimeInterval(5 * 86400),
                periodStart: start
            ),
        ]
        let anchor = PaceHistoryTipPresentation.periodAnchor(from: samples)
        XCTAssertNotNil(anchor)
        XCTAssertEqual(anchor!.periodStart, start)
        XCTAssertEqual(anchor!.periodDuration, 10 * 86400, accuracy: 0.5)
    }

    func testDateAtElapsedUsesAnchor() {
        let anchor = PaceHistoryTipPresentation.PeriodAnchor(
            periodStart: start,
            periodDuration: 10 * 86400
        )
        let mid = PaceHistoryTipPresentation.date(atElapsedPct: 50, anchor: anchor)
        XCTAssertEqual(mid.timeIntervalSince(start), 5 * 86400, accuracy: 0.5)
    }

    func testRelativeAgoMatchesMenuThresholds() {
        let now = start.addingTimeInterval(3600)
        XCTAssertEqual(
            PaceHistoryTipPresentation.relativeAgo(from: now.addingTimeInterval(-20), to: now),
            "just now"
        )
        XCTAssertEqual(
            PaceHistoryTipPresentation.relativeAgo(from: now.addingTimeInterval(-26 * 60), to: now),
            "26m ago"
        )
        XCTAssertEqual(
            PaceHistoryTipPresentation.relativeAgo(from: now.addingTimeInterval(-6 * 3600), to: now),
            "6h ago"
        )
    }

    func testWhenReadingsSingleFamilyOmitsPrefix() {
        let cursorAnchor = PaceHistoryTipPresentation.PeriodAnchor(
            periodStart: start,
            periodDuration: 30 * 86400
        )
        let readings = PaceHistoryTipPresentation.whenReadings(
            elapsedPct: 40,
            visibleMeterIds: [.cursor, .other],
            anchorsByFamily: [.cursor: cursorAnchor]
        )
        XCTAssertEqual(readings.count, 1)
        XCTAssertNil(readings[0].family)
        XCTAssertEqual(
            readings[0].at.timeIntervalSince(start),
            12 * 86400,
            accuracy: 0.5
        )
    }

    func testWhenReadingsBothFamiliesLabelSeparately() {
        let cursorAnchor = PaceHistoryTipPresentation.PeriodAnchor(
            periodStart: start,
            periodDuration: 30 * 86400
        )
        let grokStart = start.addingTimeInterval(20 * 86400)
        let grokAnchor = PaceHistoryTipPresentation.PeriodAnchor(
            periodStart: grokStart,
            periodDuration: 7 * 86400
        )
        let readings = PaceHistoryTipPresentation.whenReadings(
            elapsedPct: 50,
            visibleMeterIds: [.cursor, .grok],
            anchorsByFamily: [.cursor: cursorAnchor, .grok: grokAnchor]
        )
        XCTAssertEqual(readings.count, 2)
        XCTAssertEqual(readings[0].family, .cursor)
        XCTAssertEqual(readings[1].family, .grok)
        XCTAssertEqual(
            readings[0].at.timeIntervalSince(start),
            15 * 86400,
            accuracy: 0.5
        )
        XCTAssertEqual(
            readings[1].at.timeIntervalSince(grokStart),
            3.5 * 86400,
            accuracy: 0.5
        )
    }

    func testTipLeadingXFlipsAtFiftyPercent() {
        let left = PaceHistoryTipPresentation.tipLeadingX(
            elapsedPct: 40,
            plotWidth: 400,
            tipWidth: 160
        )
        XCTAssertEqual(left, 40 / 100 * 400 + 8, accuracy: 0.001)

        let right = PaceHistoryTipPresentation.tipLeadingX(
            elapsedPct: 50,
            plotWidth: 400,
            tipWidth: 160
        )
        XCTAssertEqual(right, 50 / 100 * 400 - 160 - 8, accuracy: 0.001)

        let far = PaceHistoryTipPresentation.tipLeadingX(
            elapsedPct: 74,
            plotWidth: 400,
            tipWidth: 160
        )
        XCTAssertEqual(far, 74 / 100 * 400 - 160 - 8, accuracy: 0.001)
    }
}
