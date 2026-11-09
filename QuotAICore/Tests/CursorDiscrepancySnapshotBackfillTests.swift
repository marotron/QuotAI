import XCTest
@testable import QuotAICore

final class CursorDiscrepancySnapshotBackfillTests: XCTestCase {
    private let periodStart = Date(timeIntervalSince1970: 1_700_000_000)
    private let otherPeriod = Date(timeIntervalSince1970: 1_699_000_000)

    func testJoinsCursorAndOtherSamplesAtSharedTimestamps() {
        let t1 = periodStart.addingTimeInterval(60)
        let t2 = periodStart.addingTimeInterval(120)
        let samples = [
            sample(.cursor, used: 50, at: t1),
            sample(.other, used: 40, at: t1),
            sample(.cursor, used: 51, at: t2),
            sample(.other, used: 41, at: t2),
        ]

        let snapshots = CursorDiscrepancySnapshotBackfill.snapshots(
            from: samples,
            periodStart: periodStart
        )

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots[0].timestamp, t1)
        XCTAssertEqual(snapshots[0].cursorModelsPercentUsed, 50)
        XCTAssertEqual(snapshots[0].otherModelsPercentUsed, 40)
        XCTAssertEqual(snapshots[1].timestamp, t2)
        XCTAssertEqual(snapshots[1].cursorModelsPercentUsed, 51)
        XCTAssertEqual(snapshots[1].otherModelsPercentUsed, 41)
    }

    func testKeepsPartialSnapshotsWhenOnlyOneMeterSampled() {
        let t = periodStart.addingTimeInterval(60)
        let snapshots = CursorDiscrepancySnapshotBackfill.snapshots(
            from: [sample(.cursor, used: 62, at: t)],
            periodStart: periodStart
        )

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].cursorModelsPercentUsed, 62)
        XCTAssertNil(snapshots[0].otherModelsPercentUsed)
    }

    func testIgnoresGrokSamplesAndOtherPeriods() {
        let t = periodStart.addingTimeInterval(60)
        let samples = [
            sample(.cursor, used: 50, at: t),
            sample(.other, used: 40, at: t),
            PaceHistorySample(
                meterId: .grok,
                usedPct: 10,
                elapsedPct: 10,
                timestamp: t,
                periodStart: periodStart
            ),
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 99,
                elapsedPct: 10,
                timestamp: t.addingTimeInterval(30),
                periodStart: otherPeriod
            ),
        ]

        let snapshots = CursorDiscrepancySnapshotBackfill.snapshots(
            from: samples,
            periodStart: periodStart
        )

        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].cursorModelsPercentUsed, 50)
        XCTAssertEqual(snapshots[0].otherModelsPercentUsed, 40)
    }

    func testBackfilledFlatDayYieldsUnbilledActivityAfterGrace() {
        let dayStart = periodStart.addingTimeInterval(86_400)
        let turnTime = dayStart.addingTimeInterval(10 * 3600)
        let samples = [
            sample(.cursor, used: 60.9, at: dayStart),
            sample(.other, used: 64.5, at: dayStart),
            sample(.cursor, used: 60.9, at: dayStart.addingTimeInterval(12 * 3600)),
            sample(.other, used: 64.5, at: dayStart.addingTimeInterval(12 * 3600)),
        ]
        let snapshots = CursorDiscrepancySnapshotBackfill.snapshots(
            from: samples,
            periodStart: periodStart
        )
        let turn = CursorAgentTurn(
            timestamp: turnTime,
            generationUUID: "a83679db-f9e5-4e72-8b56-c60449e43f3f",
            meter: .cursorModels,
            modelID: nil
        )

        let events = CursorDiscrepancyReconciler.reconcile(
            turns: [turn],
            snapshots: snapshots,
            now: turnTime.addingTimeInterval(5 * 60 + 1)
        )

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].kind, .unbilledActivity)
        XCTAssertEqual(events[0].timestamp, turnTime)
    }

    private func sample(
        _ meter: PaceHistoryMeterId,
        used: Double,
        at timestamp: Date
    ) -> PaceHistorySample {
        PaceHistorySample(
            meterId: meter,
            usedPct: used,
            elapsedPct: 50,
            timestamp: timestamp,
            periodStart: periodStart
        )
    }
}
