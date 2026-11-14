import XCTest
@testable import QuotAICore

final class CursorActivityStoreTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CursorActivityStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        fileURL = temporaryDirectory.appendingPathComponent("cursor-activity.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        fileURL = nil
    }

    func testPreservesNamedModelAndDeduplicatesTurns() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let turn = CursorAgentTurn(
            timestamp: period.addingTimeInterval(60),
            generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
            meter: .otherModels,
            modelID: "gpt-5.6-terra"
        )
        let store = CursorActivityStore(fileURL: fileURL)

        try store.replacePeriodIfNeeded(periodStart: period)
        try store.append(turns: [turn, turn])

        let reloaded = CursorActivityStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state.periodStart, period)
        XCTAssertEqual(reloaded.state.turns, [turn])
    }

    func testMergesNewerEndedAtWithoutDuplicatingTurn() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"
        let start = period.addingTimeInterval(60)
        let firstEnd = period.addingTimeInterval(10 * 60)
        let laterEnd = period.addingTimeInterval(50 * 60)
        let store = CursorActivityStore(fileURL: fileURL)

        try store.replacePeriodIfNeeded(periodStart: period)
        try store.append(
            turns: [
                CursorAgentTurn(
                    timestamp: start,
                    generationUUID: uuid,
                    meter: .otherModels,
                    modelID: "glm-5",
                    endedAt: firstEnd
                )
            ]
        )
        try store.append(
            turns: [
                CursorAgentTurn(
                    timestamp: start.addingTimeInterval(5),
                    generationUUID: uuid,
                    meter: .cursorModels,
                    modelID: "ignored-on-merge",
                    endedAt: laterEnd
                )
            ]
        )

        XCTAssertEqual(store.state.turns.count, 1)
        XCTAssertEqual(store.state.turns[0].timestamp, start)
        XCTAssertEqual(store.state.turns[0].meter, .otherModels)
        XCTAssertEqual(store.state.turns[0].modelID, "glm-5")
        XCTAssertEqual(store.state.turns[0].endedAt, laterEnd)
    }

    func testExtendsStoredTurnFromLaterLogChunkAfterReload() throws {
        let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"
        let store = CursorActivityStore(fileURL: fileURL)
        let initial = CursorActivityParser.parse(log: """
        2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {"generationUUID":"\(uuid)","modelId":"claude-haiku-5-5"}
        2026-11-04 13:00:12.000 [info] toolCall requestId=\(uuid)
        """)
        try store.append(turns: initial)

        let reloaded = CursorActivityStore(fileURL: fileURL)
        let update = CursorActivityParser.parse(log: """
        2026-11-04 13:50:00.000 [info] shellApproval requestId=\(uuid)
        """, knownTurns: reloaded.state.turns)
        try reloaded.append(turns: update)

        let persisted = CursorActivityStore(fileURL: fileURL).state.turns
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted[0].timestamp, initial[0].timestamp)
        XCTAssertEqual(persisted[0].modelID, "claude-haiku-5-5")
        XCTAssertEqual(persisted[0].endedAt, initial[0].timestamp.addingTimeInterval(50 * 60))
    }

    func testLegacyCompletedBackfillStillRepairsStaleNonNilEndOnce() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = CursorActivityStore.State(
            periodStart: start,
            turns: [CursorAgentTurn(
                timestamp: start,
                generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                meter: .otherModels,
                modelID: "claude-haiku-5-5",
                endedAt: start.addingTimeInterval(12)
            )],
            logByteOffsets: ["/tmp/Cursor Agent Host.log": 4_096],
            didBackfillTurnEndedAt: true
        )
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        object.removeValue(forKey: "didBackfillIncrementalTurnActivity")
        try JSONSerialization.data(withJSONObject: object).write(to: fileURL)

        let store = CursorActivityStore(fileURL: fileURL)
        XCTAssertTrue(store.state.didBackfillTurnEndedAt)
        XCTAssertTrue(store.state.needsTurnActivityBackfill)
        XCTAssertEqual(store.state.turns, legacy.turns)
        XCTAssertEqual(store.state.logByteOffsets, legacy.logByteOffsets)

        try store.markTurnEndedAtBackfilled()
        let reloaded = CursorActivityStore(fileURL: fileURL)
        XCTAssertTrue(reloaded.state.didBackfillIncrementalTurnActivity)
        XCTAssertFalse(reloaded.state.needsTurnActivityBackfill)
        try reloaded.replacePeriodIfNeeded(periodStart: start.addingTimeInterval(30 * 86_400))
        XCTAssertTrue(reloaded.state.didBackfillIncrementalTurnActivity)
        XCTAssertFalse(reloaded.state.needsTurnActivityBackfill)
    }

    func testNormalizePreservesEndedAt() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let ended = period.addingTimeInterval(30 * 60)
        let legacy = CursorActivityStore.State(
            periodStart: period,
            turns: [
                CursorAgentTurn(
                    timestamp: period.addingTimeInterval(60),
                    generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                    meter: .otherModels,
                    modelID: "composer-2.5-fast",
                    endedAt: ended
                )
            ]
        )
        try JSONEncoder().encode(legacy).write(to: fileURL, options: .atomic)

        let store = CursorActivityStore(fileURL: fileURL)

        XCTAssertEqual(store.state.turns.map(\.meter), [.cursorModels])
        XCTAssertEqual(store.state.turns.map(\.endedAt), [ended])
    }

    func testResetsAllCurrentPeriodActivityWhenPeriodChanges() throws {
        let firstPeriod = Date(timeIntervalSince1970: 1_700_000_000)
        let secondPeriod = firstPeriod.addingTimeInterval(30 * 86_400)
        let store = CursorActivityStore(fileURL: fileURL)

        try store.replacePeriodIfNeeded(periodStart: firstPeriod)
        try store.append(
            turns: [
                CursorAgentTurn(
                    timestamp: firstPeriod.addingTimeInterval(60),
                    generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                    meter: .cursorModels,
                    modelID: nil
                )
            ]
        )
        try store.append(
            snapshots: [
                CursorMeterSnapshot(
                    timestamp: firstPeriod.addingTimeInterval(120),
                    cursorModelsPercentUsed: 2,
                    otherModelsPercentUsed: 1
                )
            ]
        )
        try store.replaceLogByteOffsets([
            "/tmp/Cursor Agent Host.log": 4_096
        ])
        try store.markTurnEndedAtBackfilled()

        try store.replacePeriodIfNeeded(periodStart: secondPeriod)

        XCTAssertEqual(store.state.periodStart, secondPeriod)
        XCTAssertTrue(store.state.turns.isEmpty)
        XCTAssertTrue(store.state.snapshots.isEmpty)
        XCTAssertTrue(store.state.events.isEmpty)
        XCTAssertEqual(store.state.logByteOffsets, [
            "/tmp/Cursor Agent Host.log": 4_096
        ])
        XCTAssertTrue(store.state.didBackfillTurnEndedAt)
    }

    func testPersistsLogByteOffsetsAcrossReload() throws {
        let store = CursorActivityStore(fileURL: fileURL)
        let offsets = [
            "/tmp/Cursor Agent Host.log": UInt64(12_345),
            "/tmp/Cursor Agent Host.1.log": UInt64(67)
        ]

        try store.replaceLogByteOffsets(offsets)

        let reloaded = CursorActivityStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state.logByteOffsets, offsets)
    }

    func testLegacyActivityJSONDecodesMissingLogByteOffsetsAsEmpty() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let encoded = try JSONEncoder().encode(CursorActivityStore.State(periodStart: period))
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "logByteOffsets")
        try JSONSerialization.data(withJSONObject: object).write(to: fileURL, options: .atomic)

        let store = CursorActivityStore(fileURL: fileURL)
        XCTAssertEqual(store.state.logByteOffsets, [:])
        XCTAssertEqual(store.state.periodStart, period)
    }

    func testReplaceEventsOverwritesPriorReconcileSet() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = CursorDiscrepancyEvent(
            kind: .unbilledActivity,
            meter: .otherModels,
            timestamp: period.addingTimeInterval(60),
            generationUUIDs: ["a83679db-f9e5-4e72-8b56-c60449e43f3f"],
            modelIDs: ["glm-5"]
        )
        let fresh = CursorDiscrepancyEvent(
            kind: .unbilledActivity,
            meter: .cursorModels,
            timestamp: period.addingTimeInterval(120),
            generationUUIDs: ["b83679db-f9e5-4e72-8b56-c60449e43f3f"]
        )
        let store = CursorActivityStore(fileURL: fileURL)
        try store.replacePeriodIfNeeded(periodStart: period)
        try store.merge(events: [stale])

        try store.replace(events: [fresh])

        XCTAssertEqual(store.state.events, [fresh])
        let reloaded = CursorActivityStore(fileURL: fileURL)
        let migrated = CursorDiscrepancyEvent(
            kind: .unbilledActivity,
            meter: .cursorModels,
            timestamp: period.addingTimeInterval(120),
            generationUUIDs: ["b83679db-f9e5-4e72-8b56-c60449e43f3f"],
            modelIDs: ["auto"]
        )
        XCTAssertEqual(reloaded.state.events, [migrated])
    }

    func testMigratesNilAndDefaultCursorModelsLabelsToAuto() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = CursorActivityStore.State(
            periodStart: period,
            turns: [
                CursorAgentTurn(
                    timestamp: period.addingTimeInterval(60),
                    generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                    meter: .cursorModels,
                    modelID: nil
                ),
                CursorAgentTurn(
                    timestamp: period.addingTimeInterval(90),
                    generationUUID: "b83679db-f9e5-4e72-8b56-c60449e43f3f",
                    meter: .cursorModels,
                    modelID: "default"
                )
            ],
            events: [
                CursorDiscrepancyEvent(
                    kind: .unbilledActivity,
                    meter: .cursorModels,
                    timestamp: period.addingTimeInterval(60),
                    generationUUIDs: ["a83679db-f9e5-4e72-8b56-c60449e43f3f"],
                    modelIDs: []
                ),
                CursorDiscrepancyEvent(
                    kind: .unbilledActivity,
                    meter: .otherModels,
                    timestamp: period.addingTimeInterval(120),
                    generationUUIDs: ["c83679db-f9e5-4e72-8b56-c60449e43f3f"],
                    modelIDs: []
                )
            ]
        )
        try JSONEncoder().encode(legacy).write(to: fileURL, options: .atomic)

        let store = CursorActivityStore(fileURL: fileURL)

        XCTAssertEqual(store.state.turns.map(\.modelID), ["auto", "auto"])
        XCTAssertEqual(store.state.events[0].modelIDs, ["auto"])
        XCTAssertEqual(store.state.events[1].modelIDs, [])

        let reloaded = CursorActivityStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state.turns.map(\.modelID), ["auto", "auto"])
        XCTAssertEqual(reloaded.state.events[0].modelIDs, ["auto"])
        XCTAssertEqual(reloaded.state.events[1].modelIDs, [])
    }

    func testNormalizesLegacyComposerTurnsAndEventsToCursorModels() throws {
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let legacy = CursorActivityStore.State(
            periodStart: period,
            turns: [
                CursorAgentTurn(
                    timestamp: period.addingTimeInterval(60),
                    generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                    meter: .otherModels,
                    modelID: "composer-2.5-fast"
                )
            ],
            events: [
                CursorDiscrepancyEvent(
                    kind: .unbilledActivity,
                    meter: .otherModels,
                    timestamp: period.addingTimeInterval(60),
                    generationUUIDs: ["a83679db-f9e5-4e72-8b56-c60449e43f3f"],
                    modelIDs: ["composer-2.5-fast"]
                )
            ]
        )
        try JSONEncoder().encode(legacy).write(to: fileURL, options: .atomic)

        let store = CursorActivityStore(fileURL: fileURL)

        XCTAssertEqual(store.state.turns.map(\.meter), [.cursorModels])
        XCTAssertEqual(store.state.turns.map(\.modelID), ["composer-2.5-fast"])
        XCTAssertEqual(store.state.events.map(\.meter), [.cursorModels])

        let reloaded = CursorActivityStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state.turns.map(\.meter), [.cursorModels])
        XCTAssertEqual(reloaded.state.events.map(\.meter), [.cursorModels])
    }
}
