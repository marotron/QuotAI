import Foundation
import XCTest
@testable import QuotAICore

final class CodexFiveHourWeeklyRatioTests: XCTestCase {
    private let shortDuration: TimeInterval = 5 * 3600
    private let longDuration: TimeInterval = 7 * 86400
    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func window(
        id: String,
        slot: String,
        used: Double?,
        duration: TimeInterval?,
        resetsAt: Date?
    ) -> CodexQuotaWindow {
        CodexQuotaWindow(
            id: id,
            bucketName: "Codex",
            slot: slot,
            usedPercent: used,
            duration: duration,
            resetsAt: resetsAt
        )
    }

    // MARK: - Window pair by duration

    func testSelectsShortAndLongWindowsByDurationNotSlot() {
        let short = window(
            id: "codex.secondary",
            slot: "secondary",
            used: 10,
            duration: shortDuration,
            resetsAt: t0.addingTimeInterval(shortDuration)
        )
        let long = window(
            id: "codex.primary",
            slot: "primary",
            used: 20,
            duration: longDuration,
            resetsAt: t0.addingTimeInterval(longDuration)
        )
        let pair = CodexFiveHourWeeklyRatioWindows.selectPair(from: [long, short])
        XCTAssertEqual(pair?.short.id, "codex.secondary")
        XCTAssertEqual(pair?.long.id, "codex.primary")
    }

    func testSelectPairReturnsNilWithoutMatchingDurations() {
        let onlyShort = window(
            id: "codex.primary",
            slot: "primary",
            used: 10,
            duration: shortDuration,
            resetsAt: t0.addingTimeInterval(1_000)
        )
        XCTAssertNil(CodexFiveHourWeeklyRatioWindows.selectPair(from: [onlyShort]))
        XCTAssertNil(CodexFiveHourWeeklyRatioWindows.selectPair(from: []))
    }

    // MARK: - Open → observe → close

    func testClosesPeriodWhenShortResetsAtChanges() {
        let tracker = CodexFiveHourWeeklyRatioTracker()
        let shortResetA = t0.addingTimeInterval(shortDuration)
        let shortResetB = shortResetA.addingTimeInterval(shortDuration)
        let longReset = t0.addingTimeInterval(longDuration)

        let first = [
            window(id: "codex.primary", slot: "primary", used: 40, duration: shortDuration, resetsAt: shortResetA),
            window(id: "codex.secondary", slot: "secondary", used: 10, duration: longDuration, resetsAt: longReset),
        ]
        XCTAssertNil(tracker.observe(windows: first, accountID: "acct", at: t0))

        let mid = [
            window(id: "codex.primary", slot: "primary", used: 97, duration: shortDuration, resetsAt: shortResetA),
            window(id: "codex.secondary", slot: "secondary", used: 28.4, duration: longDuration, resetsAt: longReset),
        ]
        XCTAssertNil(tracker.observe(windows: mid, accountID: "acct", at: t0.addingTimeInterval(3_600)))

        let closed = [
            window(id: "codex.primary", slot: "primary", used: 1, duration: shortDuration, resetsAt: shortResetB),
            window(id: "codex.secondary", slot: "secondary", used: 28.4, duration: longDuration, resetsAt: longReset),
        ]
        let record = tracker.observe(windows: closed, accountID: "acct", at: t0.addingTimeInterval(shortDuration + 60))
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.accountID, "acct")
        XCTAssertEqual(record?.peak5h ?? -1, 97, accuracy: 0.0001)
        XCTAssertEqual(record?.weeklyStart ?? -1, 10, accuracy: 0.0001)
        XCTAssertEqual(record?.weeklyEnd ?? -1, 28.4, accuracy: 0.0001)
        XCTAssertEqual(record?.weeklyDelta ?? -1, 18.4, accuracy: 0.0001)
        XCTAssertEqual(record?.impliedWeeklyPctForFull5h ?? -1, 18.4 / 0.97, accuracy: 0.0001)
        XCTAssertEqual(record?.shortResetsAt, shortResetA)
        XCTAssertEqual(record?.longResetsAt, longReset)
        XCTAssertEqual(record?.shortDurationSeconds ?? -1, shortDuration, accuracy: 0.0001)
        XCTAssertTrue(record?.sampleComplete == true)
        XCTAssertNil(record?.incompleteReason)
    }

    // MARK: - Implied % skip rules

    func testSkipsImpliedPercentWhenWeeklyResetChangesMidPeriod() {
        let tracker = CodexFiveHourWeeklyRatioTracker()
        let shortResetA = t0.addingTimeInterval(shortDuration)
        let shortResetB = shortResetA.addingTimeInterval(shortDuration)
        let longResetA = t0.addingTimeInterval(longDuration)
        let longResetB = longResetA.addingTimeInterval(longDuration)

        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 50, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: 10, duration: longDuration, resetsAt: longResetA),
            ],
            accountID: "acct",
            at: t0
        ))
        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 80, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: 12, duration: longDuration, resetsAt: longResetB),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(1_000)
        ))
        let record = tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 1, duration: shortDuration, resetsAt: shortResetB),
                window(id: "codex.secondary", slot: "secondary", used: 12, duration: longDuration, resetsAt: longResetB),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(shortDuration + 60)
        )
        XCTAssertEqual(record?.sampleComplete, false)
        XCTAssertEqual(record?.incompleteReason, .weeklyResetMidPeriod)
        XCTAssertNil(record?.impliedWeeklyPctForFull5h)
        XCTAssertEqual(record?.peak5h ?? -1, 80, accuracy: 0.0001)
    }

    func testDoesNotOpenOrRecordWhileShortWindowHasNoUsage() {
        // Idle Codex 5h: resetsAt drifts forward on each poll until first usage.
        let tracker = CodexFiveHourWeeklyRatioTracker()
        let longReset = t0.addingTimeInterval(longDuration)
        for offset in [0.0, 60.0, 120.0, 180.0] {
            let shortReset = t0.addingTimeInterval(shortDuration + offset)
            let record = tracker.observe(
                windows: [
                    window(id: "codex.primary", slot: "primary", used: 0, duration: shortDuration, resetsAt: shortReset),
                    window(id: "codex.secondary", slot: "secondary", used: 65, duration: longDuration, resetsAt: longReset),
                ],
                accountID: "acct",
                at: t0.addingTimeInterval(offset)
            )
            XCTAssertNil(record, "idle resetsAt drift must not append a record at offset \(offset)")
        }
    }

    func testOpensOnlyAfterShortWindowUsageAndStillClosesOnResetChange() {
        let tracker = CodexFiveHourWeeklyRatioTracker()
        let shortResetA = t0.addingTimeInterval(shortDuration)
        let shortResetB = shortResetA.addingTimeInterval(shortDuration)
        let longReset = t0.addingTimeInterval(longDuration)

        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 0, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: 10, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0
        ))
        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 12, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: 11, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(30)
        ))
        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 40, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: 15, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(3_600)
        ))
        let record = tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 0, duration: shortDuration, resetsAt: shortResetB),
                window(id: "codex.secondary", slot: "secondary", used: 15, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(shortDuration + 60)
        )
        XCTAssertNotNil(record)
        XCTAssertEqual(record?.peak5h ?? -1, 40, accuracy: 0.0001)
        XCTAssertEqual(record?.weeklyStart ?? -1, 11, accuracy: 0.0001)
        XCTAssertEqual(record?.weeklyEnd ?? -1, 15, accuracy: 0.0001)
        XCTAssertTrue(record?.sampleComplete == true)
        // New window is idle again — do not open until usage returns.
        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 0, duration: shortDuration, resetsAt: shortResetB.addingTimeInterval(30)),
                window(id: "codex.secondary", slot: "secondary", used: 15, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(shortDuration + 90)
        ))
    }

    func testSkipsImpliedPercentWhenUsageMissing() {
        let tracker = CodexFiveHourWeeklyRatioTracker()
        let shortResetA = t0.addingTimeInterval(shortDuration)
        let shortResetB = shortResetA.addingTimeInterval(shortDuration)
        let longReset = t0.addingTimeInterval(longDuration)

        XCTAssertNil(tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 40, duration: shortDuration, resetsAt: shortResetA),
                window(id: "codex.secondary", slot: "secondary", used: nil, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0
        ))
        let record = tracker.observe(
            windows: [
                window(id: "codex.primary", slot: "primary", used: 50, duration: shortDuration, resetsAt: shortResetB),
                window(id: "codex.secondary", slot: "secondary", used: 11, duration: longDuration, resetsAt: longReset),
            ],
            accountID: "acct",
            at: t0.addingTimeInterval(shortDuration + 60)
        )
        XCTAssertEqual(record?.sampleComplete, false)
        XCTAssertEqual(record?.incompleteReason, .missingUsage)
        XCTAssertNil(record?.impliedWeeklyPctForFull5h)
    }

    // MARK: - Append-only store

    func testAppendOnlyRoundTripDoesNotEraseOnReload() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexFiveHourWeeklyRatioTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("codex-5h-weekly-ratio.json")

        let store = CodexFiveHourWeeklyRatioStore(fileURL: url)
        let first = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0,
            accountID: "acct",
            peak5h: 97,
            weeklyStart: 10,
            weeklyEnd: 28.4,
            weeklyDelta: 18.4,
            impliedWeeklyPctForFull5h: 18.4 / 0.97,
            shortResetsAt: t0.addingTimeInterval(shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            sampleComplete: true,
            incompleteReason: nil
        )
        try store.append(first)
        XCTAssertEqual(store.records.count, 1)

        let second = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0.addingTimeInterval(shortDuration),
            accountID: "acct",
            peak5h: 0,
            weeklyStart: 28.4,
            weeklyEnd: 28.4,
            weeklyDelta: 0,
            impliedWeeklyPctForFull5h: nil,
            shortResetsAt: t0.addingTimeInterval(2 * shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            sampleComplete: false,
            incompleteReason: .peakZero
        )
        try store.append(second)

        let reloaded = CodexFiveHourWeeklyRatioStore(fileURL: url)
        XCTAssertEqual(reloaded.records.count, 2)
        XCTAssertEqual(reloaded.records[0].peak5h, 97, accuracy: 0.0001)
        XCTAssertEqual(reloaded.records[1].incompleteReason, .peakZero)
        XCTAssertEqual(reloaded.records.map(\.closedAt), [first.closedAt, second.closedAt])
    }

    func testPurgePeakZeroArtifactsRemovesOnlyPeakZeroJunk() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexFiveHourWeeklyRatioPurge-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("codex-5h-weekly-ratio.json")
        let store = CodexFiveHourWeeklyRatioStore(fileURL: url)

        let keepComplete = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0,
            accountID: "acct",
            peak5h: 40,
            weeklyStart: 10,
            weeklyEnd: 15,
            weeklyDelta: 5,
            impliedWeeklyPctForFull5h: 12.5,
            shortResetsAt: t0.addingTimeInterval(shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            shortDurationSeconds: shortDuration,
            sampleComplete: true,
            incompleteReason: nil
        )
        let keepIncomplete = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0.addingTimeInterval(60),
            accountID: "acct",
            peak5h: 50,
            weeklyStart: 15,
            weeklyEnd: nil,
            weeklyDelta: nil,
            impliedWeeklyPctForFull5h: nil,
            shortResetsAt: t0.addingTimeInterval(2 * shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            sampleComplete: false,
            incompleteReason: .missingUsage
        )
        let dropLabeled = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0.addingTimeInterval(120),
            accountID: "acct",
            peak5h: 0,
            weeklyStart: 15,
            weeklyEnd: 15,
            weeklyDelta: 0,
            impliedWeeklyPctForFull5h: nil,
            shortResetsAt: t0.addingTimeInterval(3 * shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            sampleComplete: false,
            incompleteReason: .peakZero
        )
        let dropPeakOnly = CodexFiveHourWeeklyRatioRecord(
            closedAt: t0.addingTimeInterval(180),
            accountID: "acct",
            peak5h: 0,
            weeklyStart: 15,
            weeklyEnd: 15,
            weeklyDelta: 0,
            impliedWeeklyPctForFull5h: nil,
            shortResetsAt: t0.addingTimeInterval(4 * shortDuration),
            longResetsAt: t0.addingTimeInterval(longDuration),
            sampleComplete: false,
            incompleteReason: nil
        )
        try store.append(keepComplete)
        try store.append(keepIncomplete)
        try store.append(dropLabeled)
        try store.append(dropPeakOnly)

        XCTAssertEqual(try store.purgePeakZeroArtifacts(), 2)
        XCTAssertEqual(try store.purgePeakZeroArtifacts(), 0)
        XCTAssertEqual(store.records.map(\.id), [keepComplete.id, keepIncomplete.id])

        let reloaded = CodexFiveHourWeeklyRatioStore(fileURL: url)
        XCTAssertEqual(reloaded.records.map(\.id), [keepComplete.id, keepIncomplete.id])
    }

    func testChartSpanMapsFiveHourSliceOntoSevenDayElapsed() {
        let periodStart = t0
        let periodEnd = t0.addingTimeInterval(longDuration)
        // 5h window ending at 50% of the week → [~47.0, 50.0]
        let shortEnd = periodStart.addingTimeInterval(longDuration * 0.5)
        let record = CodexFiveHourWeeklyRatioRecord(
            closedAt: shortEnd,
            accountID: "acct",
            peak5h: 40,
            weeklyStart: 10,
            weeklyEnd: 12,
            weeklyDelta: 2,
            impliedWeeklyPctForFull5h: 5,
            shortResetsAt: shortEnd,
            longResetsAt: periodEnd,
            shortDurationSeconds: shortDuration,
            sampleComplete: true,
            incompleteReason: nil
        )
        let span = CodexFiveHourWeeklyRatioChartSpan.elapsedPercentSpan(
            record: record,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
        XCTAssertNotNil(span)
        let expectedLo = ((longDuration * 0.5 - shortDuration) / longDuration) * 100
        XCTAssertEqual(span?.lo ?? -1, expectedLo, accuracy: 0.0001)
        XCTAssertEqual(span?.hi ?? -1, 50, accuracy: 0.0001)
    }

    func testChartSpanReturnsNilWhenFullyOutsideLongWindow() {
        let periodStart = t0
        let periodEnd = t0.addingTimeInterval(longDuration)
        let record = CodexFiveHourWeeklyRatioRecord(
            closedAt: periodStart.addingTimeInterval(-shortDuration),
            accountID: "acct",
            peak5h: 40,
            weeklyStart: 1,
            weeklyEnd: 2,
            weeklyDelta: 1,
            impliedWeeklyPctForFull5h: 2.5,
            shortResetsAt: periodStart,
            longResetsAt: periodEnd,
            shortDurationSeconds: shortDuration,
            sampleComplete: true,
            incompleteReason: nil
        )
        // Ends exactly at periodStart → fully outside (shortEnd <= periodStart).
        XCTAssertNil(
            CodexFiveHourWeeklyRatioChartSpan.elapsedPercentSpan(
                record: record,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
        )
    }
}
