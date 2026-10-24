import XCTest
@testable import QuotAICore

final class ChangelogParserTests: XCTestCase {
    func testParsesSingleReleaseWithSection() {
        let raw = """
        # Changelog

        ## 0.11.0 — 2026-10-21

        ### Added

        - About QuotAI window
        """

        let releases = ChangelogParser.parseReleases(raw)
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases[0].version, "0.11.0")
        XCTAssertEqual(releases[0].date, "2026-10-21")
        XCTAssertEqual(releases[0].sections.count, 1)
        XCTAssertEqual(releases[0].sections[0].title, "Added")
        XCTAssertEqual(releases[0].sections[0].items, ["About QuotAI window"])
    }

    func testEmptyOrPreambleOnlyReturnsNoReleases() {
        XCTAssertEqual(ChangelogParser.parseReleases(""), [])
        XCTAssertEqual(ChangelogParser.parseReleases("# Changelog\n\nNo releases yet."), [])
    }

    func testParsesMultipleReleasesAndSections() {
        let raw = """
        # Changelog

        ## 0.11.0 — 2026-10-21

        ### Added

        - About window

        ### Fixed

        - Focus when opening About

        ## 0.10.0 — 2026-10-19

        ### Changed

        - Enlarged dual-line text
        """

        let releases = ChangelogParser.parseReleases(raw)
        XCTAssertEqual(releases.map(\.version), ["0.11.0", "0.10.0"])
        XCTAssertEqual(releases[0].sections.map(\.title), ["Added", "Fixed"])
        XCTAssertEqual(releases[0].sections[1].items, ["Focus when opening About"])
        XCTAssertEqual(releases[1].date, "2026-10-19")
        XCTAssertEqual(releases[1].sections[0].items, ["Enlarged dual-line text"])
    }

    func testReleaseWithoutSectionsIsKeptEmpty() {
        let raw = """
        ## 0.1.0 — 2026-01-01

        Shipping notes only — no ### buckets.
        """

        let releases = ChangelogParser.parseReleases(raw)
        XCTAssertEqual(releases.count, 1)
        XCTAssertEqual(releases[0].version, "0.1.0")
        XCTAssertEqual(releases[0].sections, [])
    }
}
