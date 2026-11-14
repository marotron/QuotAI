import XCTest
@testable import QuotAICore

/// Compiles the filesystem reader into this test target to exercise real byte offsets.
final class CursorLogActivityReaderTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var logURL: URL!
    private let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CursorLogActivityReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        logURL = temporaryDirectory.appendingPathComponent("Cursor Agent Host.log")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testReadsLaterActivityFromSavedOffsetAcrossRelaunch() throws {
        let start = "2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {\"generationUUID\":\"\(uuid)\",\"modelId\":\"claude-haiku-5-5\"}\n"
        try Data(start.utf8).write(to: logURL)
        let storeURL = temporaryDirectory.appendingPathComponent("cursor-activity.json")
        let store = CursorActivityStore(fileURL: storeURL)
        let first = CursorLogActivityReader(logsDirectory: temporaryDirectory).readNewTurns(priorOffsets: [:])
        try store.append(turns: first.turns)
        try store.replaceLogByteOffsets(first.offsets)
        XCTAssertEqual(first.offsets.count, 1)
        // Directory enumeration canonicalizes /var to /private/var on macOS.
        // Persist and reuse the reader's actual cursor key, as the app does.
        let logPath = try XCTUnwrap(first.offsets.keys.first)
        XCTAssertEqual(first.offsets[logPath], UInt64(start.utf8.count))
        XCTAssertEqual(first.turns.count, 1)
        XCTAssertNil(first.turns[0].endedAt)

        let later = "2026-11-04 13:50:00.000 [info] toolCall requestId=\(uuid)\n"
        let handle = try FileHandle(forWritingTo: logURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(later.utf8))
        try handle.close()

        let reloaded = CursorActivityStore(fileURL: storeURL)
        let reader = CursorLogActivityReader(logsDirectory: temporaryDirectory)
        let second = reader.readNewTurns(priorOffsets: reloaded.state.logByteOffsets, knownTurns: reloaded.state.turns)
        try reloaded.append(turns: second.turns)
        try reloaded.replaceLogByteOffsets(second.offsets)
        XCTAssertEqual(second.offsets[logPath], UInt64((start + later).utf8.count))
        XCTAssertEqual(second.turns.count, 1)
        XCTAssertEqual(reloaded.state.turns[0].endedAt, first.turns[0].timestamp.addingTimeInterval(50 * 60))
        XCTAssertTrue(reader.readNewTurns(priorOffsets: second.offsets, knownTurns: reloaded.state.turns).turns.isEmpty)
    }

    func testWaitsForCompleteRuntimeAndActivityLines() throws {
        let start = "2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {\"generationUUID\":\"\(uuid)\",\"modelId\":\"claude-haiku-5-5\"}"
        try Data(start.utf8).write(to: logURL)
        let reader = CursorLogActivityReader(logsDirectory: temporaryDirectory)
        let incompleteStart = reader.readNewTurns(priorOffsets: [:])
        XCTAssertTrue(incompleteStart.turns.isEmpty)
        XCTAssertEqual(Array(incompleteStart.offsets.values), [0])

        try Data((start + "\n").utf8).write(to: logURL)
        let first = reader.readNewTurns(priorOffsets: incompleteStart.offsets)
        XCTAssertEqual(first.turns.count, 1)

        // The line is split in the middle of a multibyte character, as can happen
        // while Cursor writes a tool response. Neither half may be discarded.
        let later = "2026-11-04 13:50:00.000 [info] toolCall requestId=\(uuid) result=é\n"
        let bytes = Data(later.utf8)
        var partial = Data((start + "\n").utf8)
        partial.append(bytes.dropLast(2))
        try partial.write(to: logURL)
        let incompleteActivity = reader.readNewTurns(priorOffsets: first.offsets, knownTurns: first.turns)
        XCTAssertTrue(incompleteActivity.turns.isEmpty)
        XCTAssertEqual(incompleteActivity.offsets, first.offsets)

        try Data((start + "\n" + later).utf8).write(to: logURL)
        let completed = reader.readNewTurns(priorOffsets: incompleteActivity.offsets, knownTurns: first.turns)
        let updated = try XCTUnwrap(completed.turns.first)
        XCTAssertEqual(updated.endedAt, first.turns[0].timestamp.addingTimeInterval(50 * 60))
        XCTAssertEqual(Array(completed.offsets.values), [UInt64((start + "\n" + later).utf8.count)])
    }

    func testTruncatedLogExtendsRetainedTurn() throws {
        let start = "2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {\"generationUUID\":\"\(uuid)\",\"modelId\":\"claude-haiku-5-5\"}\n"
        try Data(start.utf8).write(to: logURL)
        let reader = CursorLogActivityReader(logsDirectory: temporaryDirectory)
        let first = reader.readNewTurns(priorOffsets: [:])

        let later = "2026-11-04 14:00:00.000 [info] toolCall requestId=\(uuid)\n"
        try Data(later.utf8).write(to: logURL)
        let rotated = reader.readNewTurns(priorOffsets: first.offsets, knownTurns: first.turns)
        let updated = try XCTUnwrap(rotated.turns.first)
        XCTAssertEqual(updated.timestamp, first.turns[0].timestamp)
        XCTAssertEqual(updated.endedAt, first.turns[0].timestamp.addingTimeInterval(60 * 60))
        XCTAssertEqual(Array(rotated.offsets.values), [UInt64(later.utf8.count)])
    }

    func testOneShotRescanRepairsStaleEndAfterOriginalBackfill() throws {
        let log = """
        2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {"generationUUID":"\(uuid)","modelId":"claude-haiku-5-5"}
        2026-11-04 13:00:12.000 [info] toolCall requestId=\(uuid)
        2026-11-04 14:00:00.000 [info] shellApproval requestId=\(uuid)

        """
        try Data(log.utf8).write(to: logURL)
        let firstChunk = log.components(separatedBy: "\n").prefix(2).joined(separator: "\n")
        let staleTurns = CursorActivityParser.parse(log: firstChunk)
        let storeURL = temporaryDirectory.appendingPathComponent("cursor-activity.json")
        let reader = CursorLogActivityReader(logsDirectory: temporaryDirectory)
        let legacy = CursorActivityStore.State(
            turns: staleTurns,
            logByteOffsets: reader.currentFileSizes(),
            didBackfillTurnEndedAt: true
        )
        try JSONEncoder().encode(legacy).write(to: storeURL)
        let store = CursorActivityStore(fileURL: storeURL)
        XCTAssertTrue(store.state.needsTurnActivityBackfill)

        let read = reader.readNewTurns(
            priorOffsets: store.state.needsTurnActivityBackfill ? [:] : store.state.logByteOffsets,
            knownTurns: store.state.turns
        )
        try store.append(turns: read.turns)
        try store.replaceLogByteOffsets(read.offsets)
        try store.markTurnEndedAtBackfilled()

        let reloaded = CursorActivityStore(fileURL: storeURL)
        XCTAssertFalse(reloaded.state.needsTurnActivityBackfill)
        XCTAssertEqual(reloaded.state.turns[0].endedAt, staleTurns[0].timestamp.addingTimeInterval(60 * 60))
        XCTAssertEqual(reloaded.state.logByteOffsets, read.offsets)
    }
}
