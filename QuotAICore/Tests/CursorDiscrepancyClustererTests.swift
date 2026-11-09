import XCTest
@testable import QuotAICore

final class CursorDiscrepancyElapsedTests: XCTestCase {
    func testPercentIsLinearAndClamped() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end = start.addingTimeInterval(100)

        XCTAssertEqual(
            CursorDiscrepancyElapsed.percent(
                at: start.addingTimeInterval(-10),
                periodStart: start,
                periodEnd: end
            ) ?? -1,
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CursorDiscrepancyElapsed.percent(
                at: start.addingTimeInterval(25),
                periodStart: start,
                periodEnd: end
            ) ?? -1,
            25,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            CursorDiscrepancyElapsed.percent(
                at: start.addingTimeInterval(150),
                periodStart: start,
                periodEnd: end
            ) ?? -1,
            100,
            accuracy: 0.0001
        )
    }

    func testPercentReturnsNilWhenPeriodInvalid() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(
            CursorDiscrepancyElapsed.percent(
                at: start,
                periodStart: start,
                periodEnd: start
            )
        )
    }
}

final class CursorDiscrepancyClustererTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private var end: Date { start.addingTimeInterval(100) }

    func testEmptyInputReturnsEmpty() {
        let clusters = CursorDiscrepancyClusterer.cluster(
            events: [],
            periodStart: start,
            periodEnd: end
        )
        XCTAssertTrue(clusters.isEmpty)
    }

    func testSingletonLoEqualsHi() {
        let event = makeEvent(atElapsed: 40)
        let clusters = CursorDiscrepancyClusterer.cluster(
            events: [event],
            periodStart: start,
            periodEnd: end
        )
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].elapsedLo, 40, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].elapsedHi, 40, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].centerElapsed, 40, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].events, [event])
    }

    func testMergesWhenConsecutiveGapAtMostTwoElapsedPercent() {
        let a = makeEvent(atElapsed: 10)
        let b = makeEvent(atElapsed: 12)
        let c = makeEvent(atElapsed: 12.5)
        let clusters = CursorDiscrepancyClusterer.cluster(
            events: [c, a, b],
            periodStart: start,
            periodEnd: end
        )
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].elapsedLo, 10, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].elapsedHi, 12.5, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].centerElapsed, 11.25, accuracy: 0.0001)
        XCTAssertEqual(clusters[0].events, [a, b, c])
    }

    func testSplitsWhenConsecutiveGapExceedsTwoElapsedPercent() {
        let a = makeEvent(atElapsed: 10)
        let b = makeEvent(atElapsed: 12.1)
        let clusters = CursorDiscrepancyClusterer.cluster(
            events: [a, b],
            periodStart: start,
            periodEnd: end
        )
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].events, [a])
        XCTAssertEqual(clusters[1].events, [b])
    }

    func testClampsEventsOutsidePeriodIntoZeroToHundred() {
        let early = makeEvent(timestamp: start.addingTimeInterval(-20))
        let late = makeEvent(timestamp: end.addingTimeInterval(20))
        let clusters = CursorDiscrepancyClusterer.cluster(
            events: [early, late],
            periodStart: start,
            periodEnd: end
        )
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters[0].elapsedLo, 0, accuracy: 0.0001)
        XCTAssertEqual(clusters[1].elapsedHi, 100, accuracy: 0.0001)
    }

    private func makeEvent(atElapsed elapsed: Double) -> CursorDiscrepancyEvent {
        makeEvent(timestamp: start.addingTimeInterval(elapsed))
    }

    private func makeEvent(timestamp: Date) -> CursorDiscrepancyEvent {
        CursorDiscrepancyEvent(
            kind: .unbilledActivity,
            meter: .cursorModels,
            timestamp: timestamp,
            generationUUIDs: [UUID().uuidString],
            modelIDs: ["composer-1"]
        )
    }
}
