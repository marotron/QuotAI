import XCTest
@testable import QuotAICore

final class RefreshFailureNoticeTests: XCTestCase {
    func testProvidersCursorGrokOnly() {
        XCTAssertEqual(
            RefreshFailureNotice.providers(cursorGrokFailed: true, codexFailed: false),
            [.cursor, .grok]
        )
    }

    func testProvidersCodexOnly() {
        XCTAssertEqual(
            RefreshFailureNotice.providers(cursorGrokFailed: false, codexFailed: true),
            [.codex]
        )
    }

    func testProvidersAll() {
        XCTAssertEqual(
            RefreshFailureNotice.providers(cursorGrokFailed: true, codexFailed: true),
            [.cursor, .grok, .codex]
        )
    }

    func testProvidersNone() {
        XCTAssertEqual(
            RefreshFailureNotice.providers(cursorGrokFailed: false, codexFailed: false),
            []
        )
    }

    func testJoinTwoNames() {
        XCTAssertEqual(
            RefreshFailureNotice.joinNames([.cursor, .grok]),
            "Cursor and Grok"
        )
    }

    func testJoinThreeNames() {
        XCTAssertEqual(
            RefreshFailureNotice.joinNames([.cursor, .grok, .codex]),
            "Cursor, Grok, and Codex"
        )
    }

    func testTitlePrefersCursorGrokMessage() {
        XCTAssertEqual(
            RefreshFailureNotice.title(cursorGrokMessage: "Refresh failed — offline"),
            "Refresh failed — offline"
        )
    }

    func testTitleFallbackWithoutCursorGrokMessage() {
        XCTAssertEqual(RefreshFailureNotice.title(cursorGrokMessage: nil), "Refresh failed")
        XCTAssertEqual(RefreshFailureNotice.title(cursorGrokMessage: ""), "Refresh failed")
    }

    func testBodyNamesFailedProviders() {
        let providers = RefreshFailureNotice.providers(cursorGrokFailed: true, codexFailed: false)
        XCTAssertEqual(
            RefreshFailureNotice.body(providers: providers),
            "Cursor and Grok could not refresh. Previous readings were kept. Check your connection, then try Refresh all."
        )
    }

    func testBodyCodexOnly() {
        let providers = RefreshFailureNotice.providers(cursorGrokFailed: false, codexFailed: true)
        XCTAssertEqual(
            RefreshFailureNotice.body(providers: providers),
            "Codex could not refresh. Previous readings were kept. Check your connection, then try Refresh all."
        )
    }
}
