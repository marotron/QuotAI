import XCTest
@testable import QuotAICore

final class PaceHistorySampleStoreTests: XCTestCase {
    private var tempDir: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaceHistorySampleStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        fileURL = tempDir.appendingPathComponent("pace-history.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        fileURL = nil
    }

    func testAppendAndQueryByMeterId() throws {
        let store = PaceHistorySampleStore(fileURL: fileURL)
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let stamp = Date(timeIntervalSince1970: 1_700_086_400)

        try store.append(
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 42,
                elapsedPct: 50,
                timestamp: stamp,
                periodStart: period
            )
        )
        try store.append(
            PaceHistorySample(
                meterId: .grok,
                usedPct: 10,
                elapsedPct: 20,
                timestamp: stamp,
                periodStart: period
            )
        )

        let cursor = store.series(for: .cursor)
        XCTAssertEqual(cursor.count, 1)
        XCTAssertEqual(cursor[0].usedPct, 42)
        XCTAssertEqual(cursor[0].elapsedPct, 50)
        XCTAssertEqual(cursor[0].timestamp, stamp)
        XCTAssertEqual(cursor[0].periodStart, period)

        XCTAssertEqual(store.series(for: .grok).count, 1)
        XCTAssertTrue(store.series(for: .other).isEmpty)
    }

    func testRollsSeriesWhenPeriodStartChanges() throws {
        let store = PaceHistorySampleStore(fileURL: fileURL)
        let periodA = Date(timeIntervalSince1970: 1_700_000_000)
        let periodB = Date(timeIntervalSince1970: 1_702_592_000)

        try store.append(
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 80,
                elapsedPct: 90,
                timestamp: periodA.addingTimeInterval(100),
                periodStart: periodA
            )
        )
        try store.append(
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 5,
                elapsedPct: 2,
                timestamp: periodB.addingTimeInterval(60),
                periodStart: periodB
            )
        )

        let series = store.series(for: .cursor)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].usedPct, 5)
        XCTAssertEqual(series[0].periodStart, periodB)
    }

    func testRollIsPerMeter() throws {
        let store = PaceHistorySampleStore(fileURL: fileURL)
        let periodA = Date(timeIntervalSince1970: 1_700_000_000)
        let periodB = Date(timeIntervalSince1970: 1_702_592_000)

        try store.append(
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 40,
                elapsedPct: 50,
                timestamp: periodA.addingTimeInterval(1),
                periodStart: periodA
            )
        )
        try store.append(
            PaceHistorySample(
                meterId: .other,
                usedPct: 30,
                elapsedPct: 50,
                timestamp: periodA.addingTimeInterval(1),
                periodStart: periodA
            )
        )
        try store.append(
            PaceHistorySample(
                meterId: .cursor,
                usedPct: 1,
                elapsedPct: 1,
                timestamp: periodB.addingTimeInterval(1),
                periodStart: periodB
            )
        )

        XCTAssertEqual(store.series(for: .cursor).map(\.usedPct), [1])
        XCTAssertEqual(store.series(for: .other).map(\.usedPct), [30])
    }

    func testCodableRoundTripViaFile() throws {
        let store = PaceHistorySampleStore(fileURL: fileURL)
        let period = Date(timeIntervalSince1970: 1_700_000_000)
        let stamp = Date(timeIntervalSince1970: 1_700_010_000)

        try store.append(
            PaceHistorySample(
                meterId: .other,
                usedPct: 12.5,
                elapsedPct: 33.3,
                timestamp: stamp,
                periodStart: period
            )
        )

        let reloaded = PaceHistorySampleStore(fileURL: fileURL)
        let series = reloaded.series(for: .other)
        XCTAssertEqual(series.count, 1)
        XCTAssertEqual(series[0].meterId, .other)
        XCTAssertEqual(series[0].usedPct, 12.5, accuracy: 0.0001)
        XCTAssertEqual(series[0].elapsedPct, 33.3, accuracy: 0.0001)
        XCTAssertEqual(series[0].timestamp, stamp)
        XCTAssertEqual(series[0].periodStart, period)
    }

    func testAppendMultiplePreservesOrder() throws {
        let store = PaceHistorySampleStore(fileURL: fileURL)
        let period = Date(timeIntervalSince1970: 1_700_000_000)

        try store.append(
            PaceHistorySample(
                meterId: .grok,
                usedPct: 10,
                elapsedPct: 10,
                timestamp: period.addingTimeInterval(100),
                periodStart: period
            )
        )
        try store.append(
            PaceHistorySample(
                meterId: .grok,
                usedPct: 20,
                elapsedPct: 25,
                timestamp: period.addingTimeInterval(200),
                periodStart: period
            )
        )

        XCTAssertEqual(store.series(for: .grok).map(\.usedPct), [10, 20])
    }
}
