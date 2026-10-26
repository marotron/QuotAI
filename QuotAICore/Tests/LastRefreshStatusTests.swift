import XCTest
@testable import QuotAICore

final class LastRefreshStatusTests: XCTestCase {
    private let cursor = Date(timeIntervalSince1970: 1_700_000_000)
    private let grok = Date(timeIntervalSince1970: 1_700_003_600)

    private func hhmm(_ date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    func testBusyShowsRefreshing() {
        let line = LastRefreshStatus.line(
            cursor: cursor,
            grok: grok,
            isRefreshing: true,
            formatTime: hhmm
        )
        XCTAssertEqual(line, "Refreshing…")
    }

    func testBothTimes() {
        let line = LastRefreshStatus.line(
            cursor: cursor,
            grok: grok,
            isRefreshing: false,
            formatTime: hhmm
        )
        XCTAssertEqual(
            line,
            "Last refresh: Cursor \(hhmm(cursor)) · Grok Bot \(hhmm(grok))"
        )
    }

    func testMissingGrokUsesDash() {
        let line = LastRefreshStatus.line(
            cursor: cursor,
            grok: nil,
            isRefreshing: false,
            formatTime: hhmm
        )
        XCTAssertEqual(line, "Last refresh: Cursor \(hhmm(cursor)) · Grok Bot —")
    }

    func testMissingCursorUsesDash() {
        let line = LastRefreshStatus.line(
            cursor: nil,
            grok: grok,
            isRefreshing: false,
            formatTime: hhmm
        )
        XCTAssertEqual(line, "Last refresh: Cursor — · Grok Bot \(hhmm(grok))")
    }

    func testBothMissingUseDashes() {
        let line = LastRefreshStatus.line(
            cursor: nil,
            grok: nil,
            isRefreshing: false,
            formatTime: hhmm
        )
        XCTAssertEqual(line, "Last refresh: Cursor — · Grok Bot —")
    }
}
