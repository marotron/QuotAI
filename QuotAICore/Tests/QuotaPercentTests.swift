import XCTest
@testable import QuotAICore

final class QuotaPercentTests: XCTestCase {
    func testHalfUp() {
        XCTAssertEqual(QuotaPercent.display(0.31777777777777777), 0)
        XCTAssertEqual(QuotaPercent.format(0.31777777777777777), "0%")
        XCTAssertEqual(QuotaPercent.display(15.49), 15)
        XCTAssertEqual(QuotaPercent.display(15.5), 16)
        XCTAssertEqual(QuotaPercent.display(15.56), 16)
    }

    func testZeroStaysZero() {
        XCTAssertEqual(QuotaPercent.display(0), 0)
    }

    func testWholeNumbersUnchanged() {
        XCTAssertEqual(QuotaPercent.display(47), 47)
        XCTAssertEqual(QuotaPercent.display(100), 100)
    }

    func testPreciseKeepsApiDecimals() {
        XCTAssertEqual(QuotaPercent.precise(0.31777777777777777), "0.32%")
        XCTAssertEqual(QuotaPercent.precise(46.4), "46.4%")
        XCTAssertEqual(QuotaPercent.precise(47), "47%")
        XCTAssertEqual(QuotaPercent.precise(0), "0%")
    }
}
