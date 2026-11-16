import XCTest
@testable import QuotAICore

final class ElapsedRingSegmentationTests: XCTestCase {
    func testWindowDurations() {
        for days in [1, 3, 7, 30, 31] {
            XCTAssertEqual(ElapsedRingSegmentation.count(duration: Double(days) * 86400), days)
        }
        XCTAssertEqual(ElapsedRingSegmentation.count(duration: 5 * 3600), 5)
        XCTAssertEqual(ElapsedRingSegmentation.count(duration: 30 * 86400 - 3600), 30)
        XCTAssertNil(ElapsedRingSegmentation.count(duration: nil))
        XCTAssertNil(ElapsedRingSegmentation.count(duration: 90 * 60))
        XCTAssertNil(ElapsedRingSegmentation.count(duration: .infinity))
    }

    func testWiderGapsAndPartialProgress() {
        let spans = ElapsedRingSegmentation.spans(count: 7, radius: 9.8)
        XCTAssertEqual(spans.count, 7)
        XCTAssertGreaterThan(spans[0].start, 0)
        XCTAssertLessThan(spans[0].end, spans[1].start)
        XCTAssertLessThan(spans[6].end, 100)
        let elapsed = (spans[2].start + spans[2].end) / 2
        XCTAssertGreaterThan(elapsed, spans[2].start)
        XCTAssertLessThan(elapsed, spans[2].end)
    }
}
