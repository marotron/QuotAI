import XCTest
@testable import QuotAICore

final class PaceHistoryChartDownsampleTests: XCTestCase {
    private func sample(elapsedPct: Double, usedPct: Double) -> PaceHistorySample {
        let date = Date(timeIntervalSince1970: 0)
        return PaceHistorySample(
            meterId: .cursor,
            usedPct: usedPct,
            elapsedPct: elapsedPct,
            timestamp: date,
            periodStart: date
        )
    }

    func testEmptyReturnsEmpty() {
        XCTAssertEqual(PaceHistoryChartDownsample.downsample(samples: []), [])
    }

    func testSmallSeriesKeepsSamplesAndRoundsUsedPercent() {
        let samples = [
            sample(elapsedPct: 0, usedPct: 12.34),
            sample(elapsedPct: 50, usedPct: 56.78),
        ]

        let out = PaceHistoryChartDownsample.downsample(samples: samples)

        XCTAssertEqual(out.count, samples.count)
        XCTAssertEqual(out.map(\.elapsedPct), samples.map(\.elapsedPct))
        XCTAssertEqual(out.map(\.usedPct), [12, 57])
    }

    func testDownsampleKeepsFirstLastAndPointBudget() {
        let samples = (0..<1_000).map {
            sample(elapsedPct: Double($0) / 10, usedPct: Double($0) / 10)
        }

        let out = PaceHistoryChartDownsample.downsample(samples: samples)

        XCTAssertLessThanOrEqual(out.count, PaceHistoryChartDownsample.maxPoints)
        XCTAssertEqual(out.first?.elapsedPct, samples.first?.elapsedPct)
        XCTAssertEqual(out.last?.elapsedPct, samples.last?.elapsedPct)
    }

    func testOutputElapsedIsStrictlyIncreasing() {
        let samples = (0..<1_000).map {
            sample(
                elapsedPct: Double($0) / 10,
                usedPct: sin(Double($0) / 100) * 50 + 50
            )
        }

        let out = PaceHistoryChartDownsample.downsample(samples: samples)

        for index in out.indices.dropFirst() {
            XCTAssertGreaterThan(out[index].elapsedPct, out[index - 1].elapsedPct)
        }
    }

    func testOutputUsedPercentIsQuantizedToWholePercent() {
        let samples = (0..<1_000).map {
            sample(
                elapsedPct: Double($0) / 10,
                usedPct: Double($0) / 3.0
            )
        }

        let out = PaceHistoryChartDownsample.downsample(samples: samples)

        for point in out {
            XCTAssertEqual(point.usedPct, point.usedPct.rounded())
        }
    }

    func testLTTBRetainsSharpSpike() {
        let samples = (0..<100).map { index in
            sample(
                elapsedPct: Double(index),
                usedPct: index == 50 ? 90 : 10
            )
        }

        let out = PaceHistoryChartDownsample.downsample(samples: samples, maxPoints: 10)

        XCTAssertTrue(out.contains { $0.elapsedPct == 50 && $0.usedPct == 90 })
    }
}
