import XCTest
@testable import QuotAICore

final class PaceHistoryChartModelTests: XCTestCase {
    func testOverBoundaryUsesPaceAlertBands() {
        let thresholds = PaceAlertThresholds.default
        let points = PaceHistoryChartModel.overBoundary(thresholds: thresholds)
        XCTAssertFalse(points.isEmpty)
        XCTAssertEqual(points.first?.elapsedPct ?? -1, 0, accuracy: 0.001)

        let mid = points.first { abs($0.elapsedPct - 10) < 0.5 }
        XCTAssertNotNil(mid)
        let expected = PaceAlertBands.overUsed(atElapsed: 0.10, thresholds: thresholds) * 100
        XCTAssertEqual(mid!.usedPct, expected, accuracy: 0.05)
    }

    func testUnderBoundaryStartsAtUnderAfter() {
        let thresholds = PaceAlertThresholds.default
        let points = PaceHistoryChartModel.underBoundary(thresholds: thresholds)
        XCTAssertFalse(points.isEmpty)
        XCTAssertEqual(points.first?.elapsedPct ?? -1, thresholds.underAfterPct, accuracy: 0.001)
        XCTAssertEqual(points.first?.usedPct ?? -1, 0, accuracy: 0.05)
    }

    func testVisibleLayersPassesFilterSet() {
        let filters: Set<PaceHistoryChartLayer> = [.names, .even]
        XCTAssertEqual(PaceHistoryChartModel.visibleLayers(from: filters), filters)
    }

    func testLayerCasesAreCorridorsEvenAndNames() {
        XCTAssertEqual(
            Set(PaceHistoryChartLayer.allCases),
            [.over, .under, .even, .names]
        )
    }
}

final class PaceHistoryInterpolationTests: XCTestCase {
    func testInterpolatesBetweenPoints() {
        let samples = [
            PaceHistoryChartPoint(elapsedPct: 10, usedPct: 20),
            PaceHistoryChartPoint(elapsedPct: 30, usedPct: 40),
        ]
        let mid = PaceHistoryInterpolation.usedPct(samples: samples, atElapsed: 20)
        XCTAssertEqual(mid ?? -1, 30, accuracy: 0.001)
    }

    func testNilOutsideSpan() {
        let samples = [
            PaceHistoryChartPoint(elapsedPct: 10, usedPct: 20),
            PaceHistoryChartPoint(elapsedPct: 30, usedPct: 40),
        ]
        XCTAssertNil(PaceHistoryInterpolation.usedPct(samples: samples, atElapsed: 5))
        XCTAssertNil(PaceHistoryInterpolation.usedPct(samples: samples, atElapsed: 35))
    }

    func testEmptySeries() {
        XCTAssertNil(PaceHistoryInterpolation.usedPct(samples: [], atElapsed: 10))
    }

    func testExactVertex() {
        let samples = [
            PaceHistoryChartPoint(elapsedPct: 10, usedPct: 20),
            PaceHistoryChartPoint(elapsedPct: 30, usedPct: 40),
        ]
        XCTAssertEqual(
            PaceHistoryInterpolation.usedPct(samples: samples, atElapsed: 10) ?? -1,
            20,
            accuracy: 0.001
        )
    }
}
