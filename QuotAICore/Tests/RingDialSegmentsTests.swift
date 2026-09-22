import XCTest
@testable import QuotAICore

final class RingDialSegmentsTests: XCTestCase {
    func testTimelineBrandReturnsUsedArcOnly() {
        let arcs = RingDialSegments.arcs(usedPct: 42, elapsedPct: 55, style: .timelineBrand)
        XCTAssertEqual(arcs, [
            RingDialSegments.Arc(fromPct: 0, toPct: 42, tint: .brand),
        ])
    }

    func testTimelineBrandClampsAndSkipsEmpty() {
        XCTAssertEqual(
            RingDialSegments.arcs(usedPct: 0, elapsedPct: 40, style: .timelineBrand),
            []
        )
        XCTAssertEqual(
            RingDialSegments.arcs(usedPct: 120, elapsedPct: 40, style: .timelineBrand),
            [RingDialSegments.Arc(fromPct: 0, toPct: 100, tint: .brand)]
        )
    }

    /// Proto G under: solid under used · pale ok slack to elapsed.
    func testPaceUnderPaleUnderBand() {
        let arcs = RingDialSegments.arcs(usedPct: 40, elapsedPct: 55, style: .paceUnderPale)
        XCTAssertEqual(arcs, [
            RingDialSegments.Arc(fromPct: 0, toPct: 40, tint: .under),
            RingDialSegments.Arc(fromPct: 40, toPct: 55, tint: .okPale),
        ])
    }

    /// Proto G over: solid ok to elapsed · solid over to used.
    func testPaceUnderPaleOverBand() {
        let arcs = RingDialSegments.arcs(usedPct: 70, elapsedPct: 55, style: .paceUnderPale)
        XCTAssertEqual(arcs, [
            RingDialSegments.Arc(fromPct: 0, toPct: 55, tint: .ok),
            RingDialSegments.Arc(fromPct: 55, toPct: 70, tint: .over),
        ])
    }

    /// Proto G on: solid ok used only.
    func testPaceUnderPaleOnBand() {
        // 50 / 55 ≈ 0.909 → inside 90–110% corridor
        let arcs = RingDialSegments.arcs(usedPct: 50, elapsedPct: 55, style: .paceUnderPale)
        XCTAssertEqual(arcs, [
            RingDialSegments.Arc(fromPct: 0, toPct: 50, tint: .ok),
        ])
    }

    func testPaceUnderPaleRespectsCustomDeadZone() {
        // 50/55 ≈ 0.909 → under when band is 95–105%
        let arcs = RingDialSegments.arcs(
            usedPct: 50,
            elapsedPct: 55,
            style: .paceUnderPale,
            onPaceLo: 0.95,
            onPaceHi: 1.05
        )
        XCTAssertEqual(arcs, [
            RingDialSegments.Arc(fromPct: 0, toPct: 50, tint: .under),
            RingDialSegments.Arc(fromPct: 50, toPct: 55, tint: .okPale),
        ])
    }
}
