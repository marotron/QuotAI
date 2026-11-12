import Charts
import SwiftUI
import QuotAICore

/// One Settings preview meter on the used × elapsed plane.
struct PaceAlertBandChartMeter: Equatable {
    var name: String
    var usedPct: Double
    var elapsedPct: Double
    var family: PaceAlertFamily
}

/// Live preview of smart over/under corridors (Settings Alerts pane).
/// Plot area is forced 1:1 (used × elapsed) so even-pace is a true 45° diagonal.
struct PaceAlertBandChart: View {
    var thresholds: PaceAlertThresholds
    var meters: [PaceAlertBandChartMeter]
    /// Focused family period length for hover “time left”; omit when unknown.
    var focusPeriodLength: TimeInterval? = nil
    var focusFamily: PaceAlertFamily = .cursor
    /// Square plot-area side length (axes + “Used %” sit outside this).
    var plotSide: CGFloat = 148

    private let axisTicks: [Double] = [0, 25, 50, 75, 100]

    @State private var hoverElapsed: Double?
    @State private var hoverUsed: Double?

    private var overPoints: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.overBoundary(thresholds: thresholds)
    }

    private var underPoints: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.underBoundary(thresholds: thresholds)
    }

    private var evenPoints: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.evenPaceDiagonal()
    }

    private var focusLabel: String {
        focusFamily == .grok ? "Grok Bot" : "Cursor"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            chart
            usedAxisLabel
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pace alert band chart, used percent versus elapsed percent")
    }

    private var chart: some View {
        Chart {
            corridorMarks
            meterMarks
            hoverMarks
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
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotRect: CGRect = {
                    if let anchor = proxy.plotFrame {
                        return geo[anchor]
                    }
                    return CGRect(origin: .zero, size: geo.size)
                }()
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            updateHover(at: location, proxy: proxy, plotFrame: plotRect)
                        case .ended:
                            hoverElapsed = nil
                            hoverUsed = nil
                        }
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if let hoverElapsed, let hoverUsed {
                hoverTip(elapsedPct: hoverElapsed, usedPct: hoverUsed)
                    .offset(x: 8, y: 8)
                    .allowsHitTesting(false)
            }
        }
    }

    @ChartContentBuilder
    private var corridorMarks: some ChartContent {
        ForEach(Array(evenPoints.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("Elapsed", point.elapsedPct),
                y: .value("Even", point.usedPct),
                series: .value("Series", "Even")
            )
            .foregroundStyle(.secondary)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
        }

        ForEach(Array(overPoints.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("Elapsed", point.elapsedPct),
                y: .value("Used", point.usedPct),
                series: .value("Series", "Over")
            )
            .foregroundStyle(.orange)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }

        ForEach(Array(underPoints.enumerated()), id: \.offset) { _, point in
            LineMark(
                x: .value("Elapsed", point.elapsedPct),
                y: .value("Used", point.usedPct),
                series: .value("Series", "Under")
            )
            .foregroundStyle(.blue)
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder
    private var meterMarks: some ChartContent {
        ForEach(Array(meters.enumerated()), id: \.offset) { _, meter in
            PointMark(
                x: .value("Elapsed", meter.elapsedPct),
                y: .value("Used", meter.usedPct)
            )
            .symbolSize(60)
            .foregroundStyle(meterColor(meter).opacity(meter.family == focusFamily ? 1 : 0.35))
            .annotation(position: .top, spacing: 4) {
                Text(meter.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary.opacity(meter.family == focusFamily ? 1 : 0.45))
            }
        }
    }

    @ChartContentBuilder
    private var hoverMarks: some ChartContent {
        if let hoverElapsed, let hoverUsed {
            RuleMark(x: .value("Hover X", hoverElapsed))
                .foregroundStyle(.secondary.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            RuleMark(y: .value("Hover Y", hoverUsed))
                .foregroundStyle(.secondary.opacity(0.55))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            PointMark(
                x: .value("Hover", hoverElapsed),
                y: .value("Hover", hoverUsed)
            )
            .symbolSize(36)
            .foregroundStyle(Color.accentColor)
        }
    }

    private var usedAxisLabel: some View {
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

    @ViewBuilder
    private func hoverTip(elapsedPct: Double, usedPct: Double) -> some View {
        let left = PeriodDuration.timeLeftLabel(
            elapsedFraction: elapsedPct / 100,
            periodLength: focusPeriodLength
        )
        VStack(alignment: .leading, spacing: 4) {
            Text(left.map { "\(focusLabel) · \($0)" } ?? focusLabel)
                .font(.caption2.weight(.semibold))
            HStack {
                Text("Used")
                Spacer(minLength: 8)
                Text("\(Int(usedPct.rounded()))%")
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 120, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    private func updateHover(at location: CGPoint, proxy: ChartProxy, plotFrame: CGRect) {
        guard plotFrame.contains(location),
              let elapsed: Double = proxy.value(atX: location.x - plotFrame.origin.x),
              let used: Double = proxy.value(atY: location.y - plotFrame.origin.y)
        else {
            hoverElapsed = nil
            hoverUsed = nil
            return
        }
        hoverElapsed = min(max(elapsed, 0), 100)
        hoverUsed = min(max(used, 0), 100)
    }

    /// Quiet → grey; under → blue; over / exhausted → orange (matches corridor colors).
    /// All meters are scored against the *focused* corridor (Settings preview).
    private func meterColor(_ meter: PaceAlertBandChartMeter) -> Color {
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
