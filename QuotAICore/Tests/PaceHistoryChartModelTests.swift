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

    func testLayerCasesAreCorridorsEvenNamesIconsAndDisc() {
        XCTAssertEqual(
            Set(PaceHistoryChartLayer.allCases),
            [.over, .under, .even, .names, .icons, .disc]
        )
        XCTAssertEqual(PaceHistoryChartLayer.disc.rawValue, "disc")
    }
}

final class PaceHistoryChartZoomTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(PaceHistoryChartZoom.maxZoom, 10, accuracy: 0.001)
        XCTAssertEqual(PaceHistoryChartZoom.minSpan, 10, accuracy: 0.001)
        XCTAssertEqual(PaceHistoryChartZoom.fullDomain, 0...100)
    }

    func testValidSelectionRequiresMinSpan() {
        XCTAssertTrue(PaceHistoryChartZoom.isValidSelection(span: 10))
        XCTAssertTrue(PaceHistoryChartZoom.isValidSelection(span: 25))
        XCTAssertFalse(PaceHistoryChartZoom.isValidSelection(span: 9.9))
        XCTAssertFalse(PaceHistoryChartZoom.isValidSelection(span: 0))
    }

    func testZoomFactorIsHundredOverSpan() {
        XCTAssertEqual(PaceHistoryChartZoom.zoomFactor(0...100), 1, accuracy: 0.001)
        XCTAssertEqual(PaceHistoryChartZoom.zoomFactor(40...50), 10, accuracy: 0.001)
        XCTAssertEqual(PaceHistoryChartZoom.zoomFactor(20...70), 2, accuracy: 0.001)
    }

    func testClampShiftsOverhangWhilePreservingSpan() {
        // Prototype clampDomain: shift into 0…100 without shrinking a valid span.
        XCTAssertEqual(PaceHistoryChartZoom.clamp((-5)...40), 0...45)
        XCTAssertEqual(PaceHistoryChartZoom.clamp(70...110), 60...100)
    }

    func testClampExpandsTightSpanToMinSpanAtMidpoint() {
        let clamped = PaceHistoryChartZoom.clamp(48...52)
        XCTAssertEqual(clamped.lowerBound, 45, accuracy: 0.001)
        XCTAssertEqual(clamped.upperBound, 55, accuracy: 0.001)
    }

    func testClampNestedCapPinsAtLeftEdge() {
        let clamped = PaceHistoryChartZoom.clamp((-2)...5)
        XCTAssertEqual(clamped, 0...10)
    }

    func testClampNestedCapPinsAtRightEdge() {
        let clamped = PaceHistoryChartZoom.clamp(96...105)
        XCTAssertEqual(clamped, 90...100)
    }

    func testIsZoomed() {
        XCTAssertFalse(PaceHistoryChartZoom.isZoomed(0...100))
        XCTAssertTrue(PaceHistoryChartZoom.isZoomed(10...90))
        XCTAssertTrue(PaceHistoryChartZoom.isZoomed(0...50))
    }

    func testFullDomainAxisTicksUseLabelHacks() {
        XCTAssertEqual(
            PaceHistoryChartZoom.xAxisTickValues(domain: 0...100),
            [0, 25, 50, 75, 83.5, 87.5]
        )
    }

    func testZoomedAxisTicksUseNiceSteps() {
        XCTAssertEqual(
            PaceHistoryChartZoom.xAxisTickValues(domain: 40...50),
            [40, 42, 44, 46, 48, 50]
        )
        XCTAssertEqual(
            PaceHistoryChartZoom.xAxisTickValues(domain: 20...40),
            [20, 25, 30, 35, 40]
        )
        XCTAssertEqual(
            PaceHistoryChartZoom.xAxisTickValues(domain: 10...50),
            [10, 20, 30, 40, 50]
        )
        XCTAssertEqual(
            PaceHistoryChartZoom.xAxisTickValues(domain: 0...60),
            [0, 25, 50]
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
