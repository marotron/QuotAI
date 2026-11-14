import XCTest
import CoreFoundation
@testable import QuotAICore

final class CursorUsageBillingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func turn(_ id: String = "turn", offset: Double = 0, duration: Double = 10) -> CursorAgentTurn {
        CursorAgentTurn(timestamp: now.addingTimeInterval(offset), generationUUID: id, meter: .cursorModels,
                        modelID: "auto", endedAt: now.addingTimeInterval(offset + duration), conversationID: "conversation")
    }

    private func event(_ turn: CursorAgentTurn) -> CursorDiscrepancyEvent {
        CursorDiscrepancyEvent(kind: .unbilledActivity, meter: turn.meter, timestamp: turn.timestamp, generationUUIDs: [turn.id])
    }

    private func record(_ id: String = "event", offset: Double = 0.5, chargeable: Bool? = false) -> CursorUsageBillingRecord {
        CursorUsageBillingRecord(id: id, timestamp: now.addingTimeInterval(offset), modelID: "default", conversationID: "conversation", isChargeable: chargeable)
    }

    private func checked(_ records: [CursorUsageBillingRecord], turns: [CursorAgentTurn]? = nil, complete: Bool = true) -> CursorBillingCheck? {
        CursorUsageBilling.checks(
            for: CursorUsageBillingWindow(start: now.addingTimeInterval(-2), end: now.addingTimeInterval(12), turnIDs: ["turn"]),
            records: records, complete: complete, turns: turns ?? [turn()], now: now.addingTimeInterval(600)
        )["turn"]
    }

    func testExplicitFreeRequiresCompleteUnambiguousEvidence() {
        XCTAssertEqual(checked([record()])?.status, .nonChargeable)
        XCTAssertEqual(checked([record(chargeable: true)])?.status, .chargeable)
        XCTAssertEqual(checked([record(chargeable: nil)])?.status, .unknown)
        XCTAssertEqual(checked([])?.status, .unknown)
        XCTAssertEqual(checked([record()], complete: false)?.status, .unknown)
        XCTAssertEqual(checked([record()], turns: [turn(), turn("overlapping")])?.status, .unknown)
        var wrongConversation = record()
        wrongConversation.conversationID = "other"
        XCTAssertEqual(checked([wrongConversation])?.status, .unknown)
        var wrongModel = record()
        wrongModel.modelID = "composer"
        XCTAssertEqual(checked([wrongModel])?.status, .unknown)
        XCTAssertEqual(checked([record(offset: 7)])?.status, .unknown, "A later request without a start anchor is not enough")
    }

    func testFreeFirstAttemptDoesNotHideBillableRetryOrMissingFlag() {
        XCTAssertEqual(checked([record(), record("retry", offset: 8, chargeable: true)])?.status, .chargeable)
        XCTAssertEqual(checked([record(), record("retry", offset: 8, chargeable: nil)])?.status, .unknown)
        XCTAssertEqual(checked([record(), record(chargeable: true)])?.status, .unknown, "Conflicting records cannot prove Free")
    }

    func testSelectivePlannerBatchesCapsCachesAndThrottles() {
        let turns = [turn("one"), turn("two", offset: -60), turn("three", offset: -7200), turn("four", offset: -14400)]
        let events = turns.map(event)
        let stamp = now.addingTimeInterval(600)
        let windows = CursorUsageBilling.windows(events: events, turns: turns, checks: [:], lastLookup: nil, now: stamp)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(Set(windows[0].turnIDs), ["one", "two"])
        XCTAssertEqual(windows[1].turnIDs, ["three"])
        XCTAssertTrue(CursorUsageBilling.windows(events: [], turns: turns, checks: [:], lastLookup: nil, now: stamp).isEmpty)
        XCTAssertTrue(CursorUsageBilling.windows(events: events, turns: turns, checks: [:], lastLookup: now, now: stamp.addingTimeInterval(-1)).isEmpty)
        let cached = Dictionary(uniqueKeysWithValues: turns.map {
            ($0.id, CursorBillingCheck(status: .chargeable, checkedAt: now, activityEnd: $0.endedAt!, eventIDs: ["verified"]))
        })
        XCTAssertTrue(CursorUsageBilling.windows(events: events, turns: turns, checks: cached, lastLookup: nil, now: stamp).isEmpty)
        var extended = turns[0]
        extended.endedAt = now.addingTimeInterval(20)
        XCTAssertFalse(CursorUsageBilling.windows(events: [event(extended)], turns: [extended], checks: cached, lastLookup: nil, now: stamp).isEmpty)
    }

    func testUnknownHistoricalEvidenceBacksOffAndOversizedOrUnidentifiedTurnsAreNotFetched() {
        var historical = turn(offset: -7200)
        let stamp = now.addingTimeInterval(600)
        let check = CursorBillingCheck(status: .unknown, checkedAt: now, activityEnd: historical.endedAt!, eventIDs: [])
        XCTAssertTrue(CursorUsageBilling.windows(events: [event(historical)], turns: [historical], checks: [historical.id: check], lastLookup: nil, now: stamp).isEmpty)
        XCTAssertFalse(CursorUsageBilling.windows(events: [event(historical)], turns: [historical], checks: [historical.id: check], lastLookup: nil, now: stamp.addingTimeInterval(86400)).isEmpty)
        historical.conversationID = nil
        XCTAssertTrue(CursorUsageBilling.windows(events: [event(historical)], turns: [historical], checks: [:], lastLookup: nil, now: stamp).isEmpty)
        let long = turn(duration: 7200)
        XCTAssertTrue(CursorUsageBilling.windows(events: [event(long)], turns: [long], checks: [:], lastLookup: nil, now: stamp).isEmpty)
    }

    func testFreeEvidenceSuppressesOnlyThatTurnAndExpiresOnNewActivity() throws {
        let free = turn()
        let genuine = turn("genuine", offset: 60)
        let snapshots = [
            CursorMeterSnapshot(timestamp: now.addingTimeInterval(-60), cursorModelsPercentUsed: 10, otherModelsPercentUsed: 10),
            CursorMeterSnapshot(timestamp: now.addingTimeInterval(1000), cursorModelsPercentUsed: 10, otherModelsPercentUsed: 10),
        ]
        let check = try XCTUnwrap(checked([record()]))
        let events = CursorDiscrepancyReconciler.reconcile(turns: [free, genuine], snapshots: snapshots, billingChecks: [free.id: check], now: now.addingTimeInterval(1200))
        XCTAssertEqual(events.flatMap(\.generationUUIDs), [genuine.id])
        var extended = free
        extended.endedAt = now.addingTimeInterval(30)
        XCTAssertEqual(CursorDiscrepancyReconciler.reconcile(turns: [extended], snapshots: snapshots, billingChecks: [free.id: check], now: now.addingTimeInterval(1200)).count, 1)
    }

    func testBillingCachePersistsAndClearsAtPeriodRollover() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("state.json")
        let store = CursorActivityStore(fileURL: url)
        try store.replacePeriodIfNeeded(periodStart: now)
        try store.append(turns: [turn()])
        try store.markBillingRoutingBackfilled()
        try store.merge(billingChecks: ["turn": XCTUnwrap(checked([record()]))])
        try store.recordBillingLookup(at: now)
        let reloaded = CursorActivityStore(fileURL: url)
        XCTAssertEqual(reloaded.state.billingChecks["turn"]?.status, .nonChargeable)
        XCTAssertEqual(reloaded.state.lastBillingLookupAt, now)
        XCTAssertEqual(reloaded.state.turns[0].conversationID, "conversation")
        try reloaded.replacePeriodIfNeeded(periodStart: now.addingTimeInterval(86400))
        XCTAssertTrue(reloaded.state.billingChecks.isEmpty)
        XCTAssertNil(reloaded.state.lastBillingLookupAt)
        XCTAssertTrue(reloaded.state.didBackfillBillingConversations)
    }

    func testParserNeverInfersFreeFromMissingBooleanOrZeroPrice() throws {
        let base: [String: Any] = ["usageEventId": "id", "timestamp": "1794254598799", "model": "default", "conversationId": "conversation", "chargedCents": 0]
        let flags: [Any?] = [nil, false, true, 0]
        for flag in flags {
            var row = base
            if let flag { row["isChargeable"] = flag }
            let data = try JSONSerialization.data(withJSONObject: ["totalUsageEventsCount": 1, "usageEventsDisplay": [row]])
            let page = try CursorUsageBillingPage.parse(data)
            let expected: Bool? = (flag as? NSNumber).flatMap { CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : nil }
            XCTAssertEqual(page.records[0].isChargeable, expected)
        }
        XCTAssertThrowsError(try CursorUsageBillingPage.parse(Data("{}".utf8)))
    }
}
