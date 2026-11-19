import XCTest
@testable import QuotAICore

final class PaceHistoryEndAnnotationLayoutTests: XCTestCase {
    private let plotW = 414.0
    private let plotH = 207.0

    func testFarApartEndsNeedNoOffset() {
        let ends = [
            PaceHistoryEndAnnotationLayout.End(id: .cursor, elapsedPct: 20, usedPct: 20),
            PaceHistoryEndAnnotationLayout.End(id: .other, elapsedPct: 80, usedPct: 80),
        ]
        let offsets = PaceHistoryEndAnnotationLayout.offsetsY(
            ends: ends,
            plotWidth: plotW,
            plotHeight: plotH
        )
        XCTAssertEqual(offsets[.cursor] ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(offsets[.other] ?? -1, 0, accuracy: 0.001)
    }

    func testScreenshotModelsOtherCollisionSeparatesVertically() {
        // Live screenshot: Models 93% / Other 100% at ~94% elapsed.
        let ends = [
            PaceHistoryEndAnnotationLayout.End(id: .cursor, elapsedPct: 94, usedPct: 93),
            PaceHistoryEndAnnotationLayout.End(id: .other, elapsedPct: 94, usedPct: 100),
        ]
        let offsets = PaceHistoryEndAnnotationLayout.offsetsY(
            ends: ends,
            plotWidth: plotW,
            plotHeight: plotH,
            minSeparation: 16
        )
        let sep = separation(
            ends[0], ends[1],
            dy0: offsets[.cursor] ?? 0,
            dy1: offsets[.other] ?? 0
        )
        XCTAssertGreaterThanOrEqual(sep, 16 - 0.05)
        // Other sits above Models → push Models down (or Other up), not the old hardcoded pull-together.
        XCTAssertGreaterThanOrEqual(offsets[.cursor] ?? 0, 0)
    }

    func testThreeWayClusterKeepsMinSeparation() {
        let ends = [
            PaceHistoryEndAnnotationLayout.End(id: .cursor, elapsedPct: 90, usedPct: 88),
            PaceHistoryEndAnnotationLayout.End(id: .other, elapsedPct: 91, usedPct: 92),
            PaceHistoryEndAnnotationLayout.End(id: .grok, elapsedPct: 89, usedPct: 90),
        ]
        let offsets = PaceHistoryEndAnnotationLayout.offsetsY(
            ends: ends,
            plotWidth: plotW,
            plotHeight: plotH,
            minSeparation: 16
        )
        for i in 0..<ends.count {
            for j in (i + 1)..<ends.count {
                let a = ends[i]
                let b = ends[j]
                let sep = separation(
                    a, b,
                    dy0: offsets[a.id] ?? 0,
                    dy1: offsets[b.id] ?? 0
                )
                XCTAssertGreaterThanOrEqual(sep, 16 - 0.05, "\(a.id) vs \(b.id)")
            }
        }
    }

    func testEmptyEndsReturnEmpty() {
        let offsets = PaceHistoryEndAnnotationLayout.offsetsY(
            ends: [],
            plotWidth: plotW,
            plotHeight: plotH
        )
        XCTAssertTrue(offsets.isEmpty)
    }

    private func separation(
        _ a: PaceHistoryEndAnnotationLayout.End,
        _ b: PaceHistoryEndAnnotationLayout.End,
        dy0: Double,
        dy1: Double
    ) -> Double {
        let x0 = a.elapsedPct / 100 * plotW
        let x1 = b.elapsedPct / 100 * plotW
        let y0 = plotH - a.usedPct / 100 * plotH + dy0
        let y1 = plotH - b.usedPct / 100 * plotH + dy1
        return hypot(x1 - x0, y1 - y0)
    }
}
