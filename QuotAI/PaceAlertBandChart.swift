import Charts
import SwiftUI
import QuotAICore

/// Live preview of smart over/under corridors (Settings Alerts pane).
/// Plot area is forced 1:1 (used × elapsed) so even-pace is a true 45° diagonal.
struct PaceAlertBandChart: View {
    var thresholds: PaceAlertThresholds
    var meters: [(name: String, usedPct: Double, elapsedPct: Double)]
    /// Square plot-area side length (axes + “Used %” sit outside this).
    var plotSide: CGFloat = 148

    private let samples = stride(from: 0.0, through: 1.0, by: 0.02).map { $0 }
    private let axisTicks: [Double] = [0, 25, 50, 75, 100]

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Chart {
                ForEach(samples, id: \.self) { t in
                    LineMark(
                        x: .value("Elapsed", t * 100),
                        y: .value("Even", t * 100),
                        series: .value("Series", "Even")
                    )
                    .foregroundStyle(.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                ForEach(overSamples, id: \.self) { t in
                    LineMark(
                        x: .value("Elapsed", t * 100),
                        y: .value("Used", overY(t)),
                        series: .value("Series", "Over")
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                ForEach(underSamples, id: \.self) { t in
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
                    .foregroundStyle(meterColor(meter))
                    .annotation(position: .top, spacing: 4) {
                        Text(meter.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXScale(domain: 0...100)
            .chartYScale(domain: 0...100)
            .chartXAxis {
                AxisMarks(values: axisTicks)
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: axisTicks)
            }
            .chartXAxisLabel("Elapsed %", position: .bottom, alignment: .center)
            .chartPlotStyle { plotArea in
                plotArea.frame(width: plotSide, height: plotSide)
            }

            // rotationEffect keeps pre-rotation layout size; collapse width so the
            // label sits next to the trailing ticks (same closeness as “Elapsed %”).
            Text("Used %")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 12)
                .padding(.leading, 2)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pace alert band chart, used percent versus elapsed percent")
    }

    private var overSamples: [Double] {
        let b = thresholds.overEmptyBeforePct / 100
        var pts = samples.filter { $0 <= b }
        if b > 0, b < 1, !pts.contains(where: { abs($0 - b) < 1e-9 }) {
            pts.append(b)
            pts.sort()
        }
        return pts
    }

    private var underSamples: [Double] {
        let c = thresholds.underAfterPct / 100
        var pts = samples.filter { $0 >= c }
        // Include exact `c` so the line starts on the axis at (c, 0), not the next 0.02 tick.
        if c >= 0, c < 1, !pts.contains(where: { abs($0 - c) < 1e-9 }) {
            pts.append(c)
            pts.sort()
        }
        return pts
    }

    private func overY(_ t: Double) -> Double {
        min(max(PaceAlertBands.overUsed(atElapsed: t, thresholds: thresholds) * 100, 0), 100)
    }

    private func underY(_ t: Double) -> Double {
        let c = thresholds.underAfterPct / 100
        guard t >= c else { return 0 }
        return min(max(PaceAlertBands.underUsed(atElapsed: t, thresholds: thresholds) * 100, 0), 100)
    }

    /// Quiet → grey; under → blue; over / exhausted → orange (matches corridor colors).
    private func meterColor(_ meter: (name: String, usedPct: Double, elapsedPct: Double)) -> Color {
        let kind = PaceAlertBands.evaluate(
            percentUsed: meter.usedPct,
            elapsedFraction: meter.elapsedPct / 100,
            thresholds: thresholds,
            smart: true
        )
        switch kind {
        case .quiet:
            return .gray
        case .under:
            return .blue
        case .over, .exhausted:
            return .orange
        }
    }
}
