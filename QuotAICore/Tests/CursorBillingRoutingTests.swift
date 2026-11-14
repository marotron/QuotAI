import XCTest
@testable import QuotAICore

final class CursorBillingRoutingTests: XCTestCase {
    private let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"

    private func runtime(reason: String? = nil, runtime: String = "connect") -> String {
        let reasonField = reason.map { ",\"reason\":\"\($0)\"" } ?? ""
        return "2026-11-13 23:05:22.416 [info] Selected Agent Host turn runtime {\"generationUUID\":\"\(uuid)\",\"modelId\":\"gemini-4-hydrogen\",\"runtime\":\"\(runtime)\"\(reasonField)}\n"
    }

    func testOnlyExplicitByokReasonMeansOutsideCursorBilling() throws {
        for reason in [nil, "eligible", "gate-off", "unknown", "byok-connect-routed"] as [String?] {
            let turn = try XCTUnwrap(CursorActivityParser.parse(log: runtime(reason: reason)).first)
            XCTAssertEqual(turn.routingReason, reason)
            XCTAssertEqual(turn.isOutsideCursorBilling, reason == "byok-connect-routed")
            XCTAssertEqual(turn.modelID, "gemini-4-hydrogen")
        }
    }

    func testBackfillAndLaterActivityPreserveRoutingAndLongestInterval() throws {
        var legacy = try XCTUnwrap(CursorActivityParser.parse(log: runtime()).first)
        legacy.endedAt = legacy.timestamp.addingTimeInterval(600)
        let backfilled = try XCTUnwrap(CursorActivityParser.parse(
            log: runtime(reason: "byok-connect-routed"), knownTurns: [legacy]
        ).first)
        XCTAssertTrue(backfilled.isOutsideCursorBilling)
        XCTAssertEqual(backfilled.endedAt, legacy.endedAt)

        let continued = try XCTUnwrap(CursorActivityParser.parse(
            log: "2026-11-13 23:25:22.416 [info] toolCall requestId=\(uuid)\n", knownTurns: [backfilled]
        ).first)
        XCTAssertTrue(continued.isOutsideCursorBilling)
        XCTAssertEqual(continued.endedAt, legacy.timestamp.addingTimeInterval(1200))
    }

    func testExternalTurnNeitherExpectsNorExplainsCursorQuotaIncrease() throws {
        let external = try XCTUnwrap(CursorActivityParser.parse(log: runtime(reason: "byok-connect-routed")).first)
        var managed = external
        managed.routingReason = "eligible"
        func snapshots(_ next: Double) -> [CursorMeterSnapshot] {
            [
                CursorMeterSnapshot(timestamp: external.timestamp.addingTimeInterval(-60), cursorModelsPercentUsed: 20, otherModelsPercentUsed: 30),
                CursorMeterSnapshot(timestamp: external.timestamp.addingTimeInterval(600), cursorModelsPercentUsed: 20, otherModelsPercentUsed: next),
            ]
        }
        let now = external.timestamp.addingTimeInterval(1200)
        XCTAssertTrue(CursorDiscrepancyReconciler.reconcile(turns: [external], snapshots: snapshots(30), now: now).isEmpty)
        XCTAssertEqual(CursorDiscrepancyReconciler.reconcile(turns: [managed], snapshots: snapshots(30), now: now).map(\.kind), [.unbilledActivity])
        XCTAssertEqual(CursorDiscrepancyReconciler.reconcile(turns: [external], snapshots: snapshots(31), now: now).map(\.kind), [.unattributedQuotaChange])
        XCTAssertTrue(CursorDiscrepancyReconciler.reconcile(turns: [managed], snapshots: snapshots(31), now: now).isEmpty)
    }

    func testLegacyCacheRescanPersistsRoutingAndClearsOldWarning() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let logURL = directory.appendingPathComponent("Cursor Agent Host.log")
        let storeURL = directory.appendingPathComponent("activity.json")
        let log = runtime(reason: "byok-connect-routed")
        try Data(log.utf8).write(to: logURL)
        var legacy = try XCTUnwrap(CursorActivityParser.parse(log: runtime()).first)
        legacy.endedAt = legacy.timestamp.addingTimeInterval(600)
        let samples = [
            CursorMeterSnapshot(timestamp: legacy.timestamp.addingTimeInterval(-60), cursorModelsPercentUsed: 20, otherModelsPercentUsed: 30),
            CursorMeterSnapshot(timestamp: legacy.timestamp.addingTimeInterval(1200), cursorModelsPercentUsed: 20, otherModelsPercentUsed: 30),
        ]
        let now = legacy.timestamp.addingTimeInterval(1800)
        let reader = CursorLogActivityReader(logsDirectory: directory)
        let old = CursorActivityStore.State(
            periodStart: legacy.timestamp.addingTimeInterval(-3600), turns: [legacy], snapshots: samples,
            events: CursorDiscrepancyReconciler.reconcile(turns: [legacy], snapshots: samples, now: now),
            logByteOffsets: reader.currentFileSizes(), didBackfillTurnEndedAt: true, didBackfillIncrementalTurnActivity: true
        )
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json.removeValue(forKey: "didBackfillBillingRouting")
        // A pre-change turn has no routingReason field, including no explicit null.
        var oldTurns = try XCTUnwrap(json["turns"] as? [[String: Any]])
        oldTurns[0].removeValue(forKey: "routingReason")
        json["turns"] = oldTurns
        try JSONSerialization.data(withJSONObject: json).write(to: storeURL)
        let store = CursorActivityStore(fileURL: storeURL)
        XCTAssertEqual(store.state.events.count, 1)
        XCTAssertTrue(store.state.needsBillingRoutingBackfill)
        let read = reader.readNewTurns(priorOffsets: [:], knownTurns: store.state.turns)
        XCTAssertTrue(read.isComplete)
        try store.append(turns: read.turns)
        try store.replaceLogByteOffsets(read.offsets)
        try store.markBillingRoutingBackfilled()
        try store.replace(events: CursorDiscrepancyReconciler.reconcile(turns: store.state.turns, snapshots: store.state.snapshots, now: now))

        // Older records replayed later must not erase routing evidence.
        try store.append(turns: [legacy])
        let reloaded = CursorActivityStore(fileURL: storeURL)
        XCTAssertTrue(reloaded.state.turns[0].isOutsideCursorBilling)
        XCTAssertEqual(reloaded.state.turns[0].endedAt, legacy.endedAt)
        XCTAssertTrue(reloaded.state.events.isEmpty)
        XCTAssertFalse(reloaded.state.needsBillingRoutingBackfill)
        try reloaded.replacePeriodIfNeeded(periodStart: now)
        XCTAssertTrue(reloaded.state.didBackfillBillingRouting)
    }

    func testUnreadableLogEnumerationDoesNotCompleteBackfill() {
        let reader = CursorLogActivityReader(logsDirectory: URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)"))
        XCTAssertFalse(reader.readNewTurns(priorOffsets: [:]).isComplete)
    }

    func testFailedMigrationSaveRemainsRetryable() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: blocker)
        defer { try? FileManager.default.removeItem(at: blocker) }
        let store = CursorActivityStore(fileURL: blocker.appendingPathComponent("activity.json"))
        XCTAssertThrowsError(try store.markBillingRoutingBackfilled())
        XCTAssertFalse(store.state.didBackfillBillingRouting)
    }
}
