import XCTest
@testable import QuotAICore

final class CursorDiscrepancyReconcilerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testMatchesDefaultAndNamedTurnsToTheirMeterIncreases() {
        let turns = [
            turn(offset: 10, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .cursorModels),
            turn(
                offset: 20,
                id: "b83679db-f9e5-4e72-8b56-c60449e43f3f",
                meter: .otherModels,
                modelID: "gpt-5.6-terra"
            ),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 30, cursor: 11, other: 11),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(10 * 60)
        )

        XCTAssertTrue(events.isEmpty)
    }

    func testReportsTurnWithoutMeterIncreaseAfterGraceWindow() {
        let expected = turn(
            offset: 10,
            id: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
            meter: .cursorModels
        )

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [expected],
            snapshots: [
                snapshot(offset: 0, cursor: 10, other: 10),
                snapshot(offset: 5 * 60 + 10, cursor: 10, other: 10),
            ],
            now: now.addingTimeInterval(5 * 60 + 11)
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .unbilledActivity)
        XCTAssertEqual(events[0].meter, .cursorModels)
        XCTAssertEqual(events[0].generationUUIDs, [expected.generationUUID])
    }

    func testLongTurnMatchesIncreaseDuringActivity() {
        var active = turn(offset: 10, id: "long", meter: .cursorModels)
        active.endedAt = now.addingTimeInterval(100 * 60)
        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [active],
            snapshots: [
                snapshot(offset: 0, cursor: 10, other: 10),
                snapshot(offset: 80 * 60, cursor: 10, other: 10),
                snapshot(offset: 90 * 60, cursor: 11, other: 10),
                snapshot(offset: 110 * 60, cursor: 11, other: 10),
            ], now: now.addingTimeInterval(120 * 60)
        )
        XCTAssertTrue(events.isEmpty)
    }

    func testUnbilledRequiresSameMeterCoverageAfterLatestActivityAndGrace() {
        var active = turn(offset: 10, id: "active", meter: .cursorModels)
        active.endedAt = now.addingTimeInterval(20 * 60)
        let baseline = snapshot(offset: 0, cursor: 10, other: 10)
        let later = now.addingTimeInterval(60 * 60)
        for observations in [
            [baseline],
            [baseline, snapshot(offset: 24 * 60, cursor: 10, other: 10)],
            [baseline, snapshot(offset: 30 * 60, cursor: nil, other: 10)],
            [snapshot(offset: 0, cursor: nil, other: 10), snapshot(offset: 30 * 60, cursor: 10, other: 10)],
        ] {
            XCTAssertTrue(CursorDiscrepancyReconciler.reconcile(turns: [active], snapshots: observations, now: later).isEmpty)
        }
        let covered = [baseline, snapshot(offset: 25 * 60, cursor: 10, other: 10)]
        XCTAssertEqual(CursorDiscrepancyReconciler.reconcile(turns: [active], snapshots: covered, now: later).map(\.kind), [.unbilledActivity])
    }

    func testReportsMeterIncreaseWithoutObservedTurn() {
        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [],
            snapshots: [
                snapshot(offset: 0, cursor: 10, other: 10),
                snapshot(offset: 10, cursor: 10, other: 11),
            ],
            now: now.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .unattributedQuotaChange)
        XCTAssertEqual(events[0].meter, .otherModels)
    }

    func testDoesNotJudgeActivityBeforeTheInitialMeterBaseline() {
        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [turn(offset: 10, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .cursorModels)],
            snapshots: [snapshot(offset: 20, cursor: 10, other: 10)],
            now: now.addingTimeInterval(10 * 60)
        )

        XCTAssertTrue(events.isEmpty)
    }

    func testKeepsTurnPendingAtGraceBoundary() {
        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [turn(offset: 10, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .cursorModels)],
            snapshots: [snapshot(offset: 0, cursor: 10, other: 10)],
            now: now.addingTimeInterval(5 * 60 + 10)
        )

        XCTAssertTrue(events.isEmpty)
    }

    /// Sparse pace-history gaps (≫ grace) still attribute every turn in the inter-sample
    /// window to the later increase — otherwise historical days flood with false unbilled.
    func testSparseSampleIncreaseAttributesAllTurnsInInterSampleWindow() {
        let turns = [
            turn(offset: 5 * 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
            turn(offset: 15 * 60, id: "b83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
            turn(offset: 25 * 60, id: "c83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 30 * 60, cursor: 10, other: 12),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(40 * 60)
        )

        XCTAssertTrue(events.isEmpty)
    }

    func testFlatSparseDayStillReportsUnbilledActivity() {
        let turns = [
            turn(offset: 5 * 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
            turn(offset: 15 * 60, id: "b83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 30 * 60, cursor: 10, other: 10),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(40 * 60)
        )

        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.kind == .unbilledActivity })
    }

    /// Flat intermediate snaps must not strand turns that billed a few minutes later.
    func testPlateauLookbackAttributesTurnBeforeFlatIntermediateSnapshot() {
        let turns = [
            turn(offset: 8 * 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .cursorModels),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 10 * 60, cursor: 11, other: 10), // matched elsewhere / baseline
            snapshot(offset: 12 * 60, cursor: 11, other: 10), // flat intermediate
            snapshot(offset: 15 * 60, cursor: 11.2, other: 10),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(30 * 60)
        )

        XCTAssertTrue(events.filter { $0.kind == .unbilledActivity }.isEmpty)
    }

    func testTurnShortlyAfterIncreaseStillMatches() {
        let turns = [
            turn(offset: 10 * 60 + 30, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 10 * 60, cursor: 10, other: 11),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(30 * 60)
        )

        XCTAssertTrue(events.isEmpty)
    }

    /// Trailing meter echoes after nearby activity are not "without local activity".
    func testUnattributedSuppressedWhenSameMeterTurnExistsNearby() {
        let turns = [
            turn(offset: 5 * 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 6 * 60, cursor: 10, other: 11),
            snapshot(offset: 8 * 60, cursor: 10, other: 11.05), // echo bump
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(30 * 60)
        )

        XCTAssertFalse(events.contains { $0.kind == .unattributedQuotaChange })
    }

    /// Meter lag is often well beyond the 5-minute grace: a same-meter turn 17 minutes
    /// before the bump still explains it (within the 20-minute lookback).
    func testUnattributedSuppressedWhenSameMeterTurnWithinLookbackBeforeBump() {
        let turns = [
            turn(offset: 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 17 * 60, cursor: 10, other: 10),
            snapshot(offset: 18 * 60, cursor: 10, other: 10.05),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(60 * 60)
        )

        XCTAssertFalse(events.contains { $0.kind == .unattributedQuotaChange })
    }

    /// Activity older than the lookback does not explain a bump.
    func testUnattributedStillReportedWhenLastSameMeterTurnBeyondLookback() {
        let turns = [
            turn(offset: 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 39 * 60, cursor: 10, other: 10),
            snapshot(offset: 40 * 60, cursor: 10, other: 10.05),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(2 * 60 * 60)
        )

        XCTAssertTrue(events.contains { $0.kind == .unattributedQuotaChange && $0.meter == .otherModels })
    }

    /// Long active turns: a meter bump mid-turn is explained even when start is older than lookback.
    func testUnattributedSuppressedWhenBumpOverlapsActiveTurnInterval() {
        let turns = [
            turn(
                offset: 0,
                id: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                meter: .otherModels,
                modelID: "glm-5",
                endedAtOffset: 50 * 60
            ),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 41 * 60, cursor: 10, other: 10),
            snapshot(offset: 42 * 60, cursor: 10, other: 10.05),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(60 * 60)
        )

        XCTAssertFalse(events.contains { $0.kind == .unattributedQuotaChange })
    }

    func testLaterChunkRemovesFalseBumpsInsideExtendedTurnAndMeterLagWindow() throws {
        let uuid = "a83679db-f9e5-4e72-8b56-c60449e43f3f"
        let initial = CursorActivityParser.parse(log: """
        2026-11-04 13:00:00.000 [info] Selected Agent Host turn runtime {"generationUUID":"\(uuid)","modelId":"claude-haiku-5-5"}
        2026-11-04 13:00:12.000 [info] toolCall requestId=\(uuid)
        """)
        let start = try XCTUnwrap(initial.first).timestamp
        func sample(_ minutes: Double, _ other: Double) -> CursorMeterSnapshot {
            CursorMeterSnapshot(
                timestamp: start.addingTimeInterval(minutes * 60),
                cursorModelsPercentUsed: 10,
                otherModelsPercentUsed: other
            )
        }
        let samples = [
            sample(-1, 98.4), sample(15, 98.8), sample(40, 98.8),
            sample(46, 98.9), sample(57, 99.1), sample(73, 99.2),
        ]
        let now = start.addingTimeInterval(90 * 60)
        let before = CursorDiscrepancyReconciler.reconcile(turns: initial, snapshots: samples, now: now)
        XCTAssertEqual(before.filter { $0.kind == .unattributedQuotaChange }.count, 3)

        let updated = CursorActivityParser.parse(log: """
        2026-11-04 14:00:00.000 [info] shellApproval requestId=\(uuid)
        """, knownTurns: initial)
        let after = CursorDiscrepancyReconciler.reconcile(turns: updated, snapshots: samples, now: now)
        XCTAssertTrue(after.isEmpty)

        let cursorBump = sample(74, 99.2)
        let otherMeterSample = CursorMeterSnapshot(
            timestamp: cursorBump.timestamp,
            cursorModelsPercentUsed: 11,
            otherModelsPercentUsed: 99.2
        )
        let withWrongMeter = CursorDiscrepancyReconciler.reconcile(
            turns: updated, snapshots: samples + [otherMeterSample], now: now
        )
        XCTAssertEqual(withWrongMeter.map(\.kind), [.unattributedQuotaChange])
        XCTAssertEqual(withWrongMeter.map(\.meter), [.cursorModels])
    }

    /// After a short turn ends, bumps past lookback from that end remain unattributed.
    func testUnattributedStillReportedWhenBumpBeyondLookbackAfterTurnEnded() {
        let turns = [
            turn(
                offset: 0,
                id: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
                meter: .otherModels,
                modelID: "glm-5",
                endedAtOffset: 5 * 60
            ),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 39 * 60, cursor: 10, other: 10),
            snapshot(offset: 40 * 60, cursor: 10, other: 10.05),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(60 * 60)
        )

        XCTAssertTrue(events.contains { $0.kind == .unattributedQuotaChange && $0.meter == .otherModels })
    }

    /// A turn on the other meter never explains a bump, however close.
    func testUnattributedNotSuppressedByOtherMeterTurnInLookback() {
        let turns = [
            turn(offset: 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .cursorModels),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 17 * 60, cursor: 10, other: 10),
            snapshot(offset: 18 * 60, cursor: 10, other: 10.05),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(60 * 60)
        )

        XCTAssertTrue(events.contains { $0.kind == .unattributedQuotaChange && $0.meter == .otherModels })
    }

    /// Long flat stretches (true unbilled days) must not be absorbed by a later increase.
    func testLongFlatDayNotAttributedAcrossCappedPlateauLookback() {
        let turns = [
            turn(offset: 60 * 60, id: "a83679db-f9e5-4e72-8b56-c60449e43f3f", meter: .otherModels, modelID: "glm-5"),
        ]
        let snapshots = [
            snapshot(offset: 0, cursor: 10, other: 10),
            snapshot(offset: 60 * 60, cursor: 10, other: 10),
            snapshot(offset: 2 * 60 * 60, cursor: 10, other: 10),
            snapshot(offset: 3 * 60 * 60, cursor: 10, other: 12),
        ]

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: turns,
            snapshots: snapshots,
            now: now.addingTimeInterval(4 * 60 * 60)
        )

        XCTAssertEqual(events.filter { $0.kind == .unbilledActivity }.count, 1)
    }

    private func turn(
        offset: TimeInterval,
        id: String,
        meter: CursorMeterClassification,
        modelID: String? = nil,
        endedAtOffset: TimeInterval? = nil
    ) -> CursorAgentTurn {
        CursorAgentTurn(
            timestamp: now.addingTimeInterval(offset),
            generationUUID: id,
            meter: meter,
            modelID: modelID,
            endedAt: endedAtOffset.map { now.addingTimeInterval($0) }
        )
    }

    private func snapshot(offset: TimeInterval, cursor: Double?, other: Double?) -> CursorMeterSnapshot {
        CursorMeterSnapshot(
            timestamp: now.addingTimeInterval(offset),
            cursorModelsPercentUsed: cursor,
            otherModelsPercentUsed: other
        )
    }
}
