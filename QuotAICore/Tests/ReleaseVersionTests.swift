import XCTest
@testable import QuotAICore

final class ReleaseVersionTests: XCTestCase {
    func testCandidateAndFinalLabels() {
        XCTAssertEqual(ReleaseVersion.label(marketing: "0.19.3", candidate: 1), "0.19.3-rc.1")
        XCTAssertEqual(ReleaseVersion.label(marketing: "0.19.3", candidate: 2), "0.19.3-rc.2")
        XCTAssertEqual(ReleaseVersion.label(marketing: "0.19.3", candidate: 0), "0.19.3")
    }

    func testUnreleasedNotesRemainVisibleAlongsideShippedHistory() {
        let releases = ChangelogParser.parseReleases("""
        # Changelog
        ## [Unreleased]
        ### Fixed
        - Candidate fix
        ## 0.19.2 — 2026-11-12
        ### Fixed
        - Published fix
        """)
        XCTAssertEqual(releases.map(\.version), ["Unreleased", "0.19.2"])
        XCTAssertEqual(releases.first?.sections.first?.items, ["Candidate fix"])
        XCTAssertEqual(releases.first?.date, "")
    }
}
