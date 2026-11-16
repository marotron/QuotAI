import Foundation
import XCTest
@testable import QuotAICore

final class CodexPaceHistoryTests: XCTestCase {
    func testWindowSampleRequiresUsableReadingAndFutureReset() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        var window = CodexQuotaWindow(id: "codex.primary", bucketName: "Codex", slot: "primary",
                                      usedPercent: 23, duration: 18_000, resetsAt: now.addingTimeInterval(13_500))
        let sample = window.paceHistorySample(at: now)
        XCTAssertEqual(sample?.meterId, .codex("codex.primary"))
        XCTAssertEqual(sample?.elapsedPct ?? -1, 25, accuracy: 0.0001)
        window.usedPercent = nil
        XCTAssertNil(window.paceHistorySample(at: now))
        window.usedPercent = 0
        XCTAssertNotNil(window.paceHistorySample(at: now))
        window.duration = nil
        XCTAssertNil(window.paceHistorySample(at: now))
        window.duration = 18_000
        window.resetsAt = now
        XCTAssertNil(window.paceHistorySample(at: now))
    }

    func testSeparateWindowsPersistRollIndependentlyAndClearWithoutTouchingCursor() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let store = PaceHistorySampleStore(fileURL: url)
        let now = Date(timeIntervalSince1970: 1_000_000)
        func sample(_ id: PaceHistoryMeterId, _ start: Date) -> PaceHistorySample {
            PaceHistorySample(meterId: id, usedPct: 25, elapsedPct: 50, timestamp: now, periodStart: start)
        }
        let first = PaceHistoryMeterId.codex("codex.primary")
        let second = PaceHistoryMeterId.codex("codex.secondary")
        try store.append(contentsOf: [sample(.cursor, now), sample(first, now), sample(second, now)])
        try store.append(sample(first, now.addingTimeInterval(100)))
        let reloaded = PaceHistorySampleStore(fileURL: url)
        XCTAssertEqual(reloaded.series(for: first).count, 1)
        XCTAssertEqual(reloaded.series(for: first).first?.periodStart, now.addingTimeInterval(100))
        XCTAssertEqual(reloaded.series(for: second).count, 1)
        XCTAssertEqual(reloaded.series(for: .cursor).count, 1)
        try reloaded.removeCodexHistory()
        let cleared = PaceHistorySampleStore(fileURL: url)
        XCTAssertTrue(cleared.series(for: first).isEmpty)
        XCTAssertTrue(cleared.series(for: second).isEmpty)
        XCTAssertEqual(cleared.series(for: .cursor).count, 1)
    }
    func testCodexWindowsHaveIndependentFiltersAndTipFamilies() {
        let primary = PaceHistoryMeterId.codex("codex.primary")
        let secondary = PaceHistoryMeterId.codex("codex.secondary")
        let solo = PaceHistorySeriesFilter.all.cycling(tapped: primary)
        XCTAssertTrue(solo.isVisible(primary))
        XCTAssertFalse(solo.isVisible(secondary))
        XCTAssertFalse(solo.isVisible(.cursor))
        XCTAssertNotEqual(PaceHistoryTipPresentation.billingFamily(for: primary),
                          PaceHistoryTipPresentation.billingFamily(for: secondary))
        XCTAssertEqual(solo.cycling(tapped: primary).avatarCycle(for: primary), .hide)
    }

    func testLegacyMeterIDsDecodeAsBefore() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(PaceHistoryMeterId.self, from: Data("\"cursor\"".utf8)), .cursor)
        XCTAssertEqual(try decoder.decode(PaceHistoryMeterId.self, from: Data("\"other\"".utf8)), .other)
        XCTAssertEqual(try decoder.decode(PaceHistoryMeterId.self, from: Data("\"grok\"".utf8)), .grok)
        let id = PaceHistoryMeterId.codex("extra.feature.primary")
        XCTAssertEqual(try decoder.decode(PaceHistoryMeterId.self, from: JSONEncoder().encode(id)), id)
    }

}
