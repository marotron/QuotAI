import Charts
import SwiftUI
import QuotAICore

/// Live preview of smart over/under corridors (Settings Alerts pane).
struct PaceAlertBandChart: View {
    var thresholds: PaceAlertThresholds
    var meters: [(name: String, usedPct: Double, elapsedPct: Double)]

    private let samples = stride(from: 0.0, through: 1.0, by: 0.02).map { $0 }

    var body: some View {
        Chart {
            // Even-pace reference (not an alert boundary).
            ForEach(samples, id: \.self) { t in
                LineMark(
                    x: .value("Elapsed", t * 100),
                    y: .value("Even", t * 100),
                    series: .value("Series", "Even")
                )
                .foregroundStyle(.secondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }

            // Over boundary: (0, maxStart) → (emptyBefore, 100%).
            ForEach(samples, id: \.self) { t in
                LineMark(
                    x: .value("Elapsed", t * 100),
                    y: .value("Used", overY(t)),
                    series: .value("Series", "Over")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Under boundary: (underAfter, 0) → (100%, minEnd). Only drawn once under alerts apply.
            ForEach(samples.filter { $0 >= thresholds.underAfterPct / 100 }, id: \.self) { t in
                LineMark(
                    x: .value("Elapsed", t * 100),
                    y: .value("Used", underY(t)),
                    series: .value("Series", "Under")
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(Array(meters.enumerated()), id: \.offset) { _, meter in
                PointMark(
                    x: .value("Elapsed", meter.elapsedPct),
                    y: .value("Used", meter.usedPct)
                )
                .symbolSize(60)
                .foregroundStyle(.primary)
                .annotation(position: .top, spacing: 4) {
                    Text(meter.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXScale(domain: 0...100)
        .chartYScale(domain: 0...100)
        .chartXAxisLabel("Elapsed % of period")
        .chartYAxisLabel("Used %")
        .frame(height: 200)
    }

    private func overY(_ t: Double) -> Double {
        min(max(PaceAlertBands.overUsed(atElapsed: t, thresholds: thresholds) * 100, 0), 100)
    }

    private func underY(_ t: Double) -> Double {
        let c = thresholds.underAfterPct / 100
        guard t > c else { return 0 }
        return min(max(PaceAlertBands.underUsed(atElapsed: t, thresholds: thresholds) * 100, 0), 100)
    }
}
