import Charts
import SwiftUI
import QuotAICore

/// Panel pace-history plot: 2:1 used × elapsed with corridors, trajectories, and hover tip.
struct PaceHistoryChart: View {
    var thresholds: PaceAlertThresholds
    var series: [PaceHistoryMeterId: [PaceHistorySample]]
    var showOtherModels: Bool

    @State private var visibleLayers: Set<PaceHistoryChartLayer> = Set(PaceHistoryChartLayer.allCases)
    @State private var hoverElapsed: Double?
    @Environment(\.colorScheme) private var colorScheme

    /// Panel 470 − 14×2 well margin − 14×2 well pad (same fill as proto `svg { width:100% }`).
    /// Fixed — no GeometryReader↔@State loop (that hung Charts / Metal on open).
    private let plotW: CGFloat = 414
    private var plotH: CGFloat { plotW / 2 }
    /// 22 — gutter below the plot that hosts the outside x-axis labels.
    private let axisPadBottom: CGFloat = 22
    /// 83.5 hosts the "Elapsed" title in the gap between the 75% label and the
    /// right-aligned "100%" (label-only strip); 87.5 hosts the x "100%" label
    /// between 75 and the right edge (no tick at 100 — the corner label would
    /// crowd the right spine).
    private let axisTicks: [Double] = [0, 25, 50, 75, 83.5, 87.5]
    /// Y-only: 87.5 hosts the rotated "Used %" title between 100 and 75.
    private let axisTicksY: [Double] = [0, 25, 50, 75, 87.5, 100]

    private static let cursorColor = Color(red: 0x8b / 255, green: 0x5c / 255, blue: 0xf6 / 255)
    private static let otherColor = Color(red: 0xd9 / 255, green: 0x46 / 255, blue: 0xef / 255)
    private static let grokColor = Color(red: 0xc0 / 255, green: 0x84 / 255, blue: 0xfc / 255)
    private static let evenColor = Color(red: 0x86 / 255, green: 0x86 / 255, blue: 0x8b / 255)
    private static let overFill = Color(red: 1, green: 0x9f / 255, blue: 0x0a / 255)
    private static let underFill = Color(red: 0x0a / 255, green: 0x84 / 255, blue: 1)
    private static let tertiary = Color(red: 0x8e / 255, green: 0x8e / 255, blue: 0x93 / 255)

    /// Plot box hairline — mirrors `MenuBarWindowPanel.divider` (card border).
    private var chartBoxBorder: Color {
        colorScheme == .dark
            ? Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3c / 255)
            : Color(red: 0xd2 / 255, green: 0xd2 / 255, blue: 0xd7 / 255)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chartBody
                .frame(width: plotW, height: plotH + axisPadBottom)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pace history chart, used percent versus elapsed percent")

            legend
        }
    }

    private var chartBody: some View {
        Chart {
            overMarks
            underMarks
            evenMarks
            seriesMarks
            hoverMarks
        }
        .chartXScale(domain: 0...100)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: axisTicks) { value in
                // Interior dashed grid only — 0/100 sit on the solid axis rect;
                // 87.5 and 83.5 are label-only strips (no grid).
                if let n = value.as(Double.self), !isPlotPerimeterTick(n),
                   abs(n - 87.5) > 0.01, abs(n - 83.5) > 0.01 {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                if let n = value.as(Double.self) {
                    AxisValueLabel {
                        xTickLabel(n)
                    }
                }
            }
        }
        .chartYAxis {
            // `.inset` draws labels inside the plot at the leading edge
            // (proto `data-yaxis="inside"`); no gutter is reserved either side.
            AxisMarks(preset: .inset, position: .leading, values: axisTicksY) { value in
                if let n = value.as(Double.self), !isPlotPerimeterTick(n),
                   abs(n - 87.5) > 0.01 {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                AxisValueLabel(anchor: .leading) {
                    if let n = value.as(Double.self) {
                        yTickLabel(n)
                    }
                }
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .frame(width: plotW, height: plotH)
                // Same hairline as the chart card border in MenuBarWindowPanel
                // (`divider` 0.8 / 0.5pt) — lighter than the old secondary 0.45.
                .overlay(
                    Rectangle()
                        .strokeBorder(chartBoxBorder.opacity(0.8), lineWidth: 0.5)
                )
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                let plotOrigin: CGFloat = {
                    if let anchor = proxy.plotFrame {
                        return geo[anchor].origin.x
                    }
                    return 0
                }()
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let localX = location.x - plotOrigin
                            if let elapsed: Double = proxy.value(atX: localX) {
                                hoverElapsed = min(max(elapsed, 0), 100)
                            }
                        case .ended:
                            hoverElapsed = nil
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if let hoverElapsed, !hoverDots.isEmpty {
                            tipView(elapsed: hoverElapsed)
                                .offset(
                                    tipOffset(
                                        in: geo.size,
                                        plotOrigin: plotOrigin,
                                        elapsed: hoverElapsed
                                    )
                                )
                        }
                    }
            }
        }
        .chartLegend(.hidden)
    }

    // MARK: - Chart content builders

    @ChartContentBuilder
    private var overMarks: some ChartContent {
        if visibleLayers.contains(.over) {
            ForEach(overBoundary, id: \.elapsedPct) { pt in
                AreaMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    yStart: .value("Boundary", pt.usedPct),
                    yEnd: .value("Top", 100.0),
                    series: .value("Layer", "OverFill")
                )
                .foregroundStyle(Self.overFill.opacity(0.16))
            }
            ForEach(overBoundary, id: \.elapsedPct) { pt in
                LineMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    y: .value("Used", pt.usedPct),
                    series: .value("Layer", "Over")
                )
                .foregroundStyle(Self.overFill)
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3.5, 2.5]))
            }
        }
    }

    @ChartContentBuilder
    private var underMarks: some ChartContent {
        if visibleLayers.contains(.under) {
            ForEach(underBoundary, id: \.elapsedPct) { pt in
                AreaMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    yStart: .value("Bottom", 0.0),
                    yEnd: .value("Boundary", pt.usedPct),
                    series: .value("Layer", "UnderFill")
                )
                .foregroundStyle(Self.underFill.opacity(0.16))
            }
            ForEach(underBoundary, id: \.elapsedPct) { pt in
                LineMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    y: .value("Used", pt.usedPct),
                    series: .value("Layer", "Under")
                )
                .foregroundStyle(Self.underFill)
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3.5, 2.5]))
            }
        }
    }

    @ChartContentBuilder
    private var evenMarks: some ChartContent {
        if visibleLayers.contains(.even) {
            ForEach(evenDiagonal, id: \.elapsedPct) { pt in
                LineMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    y: .value("Used", pt.usedPct),
                    series: .value("Layer", "Even")
                )
                .foregroundStyle(Self.evenColor.opacity(0.85))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
    }

    @ChartContentBuilder
    private var seriesMarks: some ChartContent {
        // One LineMark stream per meter (series tag). Short elapsed spans still
        // get a visible path via sample PointMarks + stroked end caps.
        ForEach(plottedMeterIds, id: \.rawValue) { meterId in
            ForEach(seriesPoints(for: meterId)) { row in
                LineMark(
                    x: .value("Elapsed", row.elapsedPct),
                    y: .value("Used", row.usedPct),
                    series: .value("Meter", meterId.rawValue)
                )
                .foregroundStyle(color(for: meterId))
                .opacity(0.75)
                .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
            }
            // Reading dots only — leave the latest sample to the end-cap marks below.
            ForEach(seriesReadingPoints(for: meterId)) { row in
                PointMark(
                    x: .value("Elapsed", row.elapsedPct),
                    y: .value("Used", row.usedPct)
                )
                .symbolSize(4)
                .foregroundStyle(color(for: meterId))
            }
        }

        ForEach(seriesEndPoints) { end in
            // Current tip: halo + core, only slightly larger than reading dots.
            PointMark(
                x: .value("Elapsed", end.elapsedPct),
                y: .value("Used", end.usedPct)
            )
            .symbolSize(30)
            .foregroundStyle(Color(nsColor: .windowBackgroundColor))
            PointMark(
                x: .value("Elapsed", end.elapsedPct),
                y: .value("Used", end.usedPct)
            )
            .symbolSize(20)
            .foregroundStyle(color(for: end.meterId))
            .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                if visibleLayers.contains(.names) {
                    HStack(spacing: 2) {
                        // Other has no dedicated avatar asset — reuse the Cursor
                        // avatar inked in the Other fuchsia, matching the meter row.
                        Image(nsImage: BarIcon.tintedAvatar(
                            end.meterId == .grok ? .grok : .cursor,
                            ink: nsColor(for: end.meterId),
                            pointSize: 10
                        ))
                        .frame(width: 10, height: 10)
                        Text(endLabel(for: end.meterId))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(color(for: end.meterId))
                            .shadow(color: Color(nsColor: .windowBackgroundColor).opacity(0.7), radius: 1.2)
                    }
                    .offset(y: nameNudgeY(for: end.meterId))
                }
            }
        }
    }

    @ChartContentBuilder
    private var hoverMarks: some ChartContent {
        if let hoverElapsed {
            RuleMark(x: .value("Hover", hoverElapsed))
                .foregroundStyle(Color.primary.opacity(0.28))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))

            ForEach(hoverDots) { dot in
                PointMark(
                    x: .value("Elapsed", hoverElapsed),
                    y: .value("Used", dot.used)
                )
                .symbolSize(50)
                .foregroundStyle(dot.color)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            legendChip(.over, title: "Over corridor") {
                Capsule().fill(Self.overFill).frame(width: 10, height: 3)
            }
            legendChip(.under, title: "Under corridor") {
                Capsule().fill(Self.underFill).frame(width: 10, height: 3)
            }
            legendChip(.even, title: "Exact pace") {
                // Discrete capsules match Over/Under swatches — stroked dashes alias badly at 1pt.
                HStack(spacing: 1.5) {
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                }
                .frame(width: 12, height: 8)
            }
            Spacer(minLength: 4)
            legendChip(.names, title: "Names") {
                Image(systemName: visibleLayers.contains(.names) ? "eye" : "eye.slash")
                    .font(.system(size: 10))
                    .frame(width: 12, height: 8)
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart layer filters")
    }

    private func legendChip<Swatch: View>(
        _ layer: PaceHistoryChartLayer,
        title: String,
        @ViewBuilder swatch: () -> Swatch
    ) -> some View {
        let on = visibleLayers.contains(layer)
        return Button {
            if on {
                visibleLayers.remove(layer)
            } else {
                visibleLayers.insert(layer)
            }
        } label: {
            HStack(spacing: 4) {
                swatch()
                Text(title)
                    .strikethrough(!on)
            }
            .padding(.leading, 5)
            .padding(.trailing, 7)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    )
            )
            .opacity(on ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityLabel(title)
        .accessibilityValue(on ? "Shown" : "Hidden")
    }

    // MARK: - Data

    private var plottedMeterIds: [PaceHistoryMeterId] {
        var ids: [PaceHistoryMeterId] = [.cursor, .grok]
        if showOtherModels { ids.insert(.other, at: 1) }
        return ids.filter { !(series[$0] ?? []).isEmpty }
    }

    private var overBoundary: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.overBoundary(thresholds: thresholds)
    }

    private var underBoundary: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.underBoundary(thresholds: thresholds)
    }

    private var evenDiagonal: [PaceHistoryChartPoint] {
        PaceHistoryChartModel.evenPaceDiagonal()
    }

    private struct SeriesPoint: Identifiable {
        var id: String { "\(meterId.rawValue)-\(index)" }
        var index: Int
        var meterId: PaceHistoryMeterId
        var elapsedPct: Double
        var usedPct: Double
    }

    private func seriesPoints(for meterId: PaceHistoryMeterId) -> [SeriesPoint] {
        (series[meterId] ?? []).enumerated().map { idx, sample in
            SeriesPoint(
                index: idx,
                meterId: meterId,
                elapsedPct: sample.elapsedPct,
                usedPct: sample.usedPct
            )
        }
    }

    /// All samples except the latest (drawn as the smaller current end-cap).
    private func seriesReadingPoints(for meterId: PaceHistoryMeterId) -> [SeriesPoint] {
        let pts = seriesPoints(for: meterId)
        guard pts.count > 1 else { return [] }
        return Array(pts.dropLast())
    }

    private var seriesEndPoints: [SeriesPoint] {
        plottedMeterIds.compactMap { meterId in
            guard let last = series[meterId]?.last else { return nil }
            return SeriesPoint(
                index: 0,
                meterId: meterId,
                elapsedPct: last.elapsedPct,
                usedPct: last.usedPct
            )
        }
    }

    private func chartPoints(for meterId: PaceHistoryMeterId) -> [PaceHistoryChartPoint] {
        (series[meterId] ?? []).map {
            PaceHistoryChartPoint(elapsedPct: $0.elapsedPct, usedPct: $0.usedPct)
        }
    }

    private func color(for meterId: PaceHistoryMeterId) -> Color {
        switch meterId {
        case .cursor: return Self.cursorColor
        case .other: return Self.otherColor
        case .grok: return Self.grokColor
        }
    }

    private struct HoverDot: Identifiable {
        var id: PaceHistoryMeterId
        var used: Double
        var color: Color
    }

    private var hoverDots: [HoverDot] {
        guard let hoverElapsed else { return [] }
        return plottedMeterIds.compactMap { id in
            guard let used = PaceHistoryInterpolation.usedPct(
                samples: chartPoints(for: id),
                atElapsed: hoverElapsed
            ) else { return nil }
            return HoverDot(id: id, used: used, color: color(for: id))
        }
    }

    // MARK: - Axis / tip chrome

    /// Outer plot edge is the solid axis rect — skip dashed grid on 0 / 100.
    private func isPlotPerimeterTick(_ n: Double) -> Bool {
        abs(n) < 0.5 || abs(n - 100) < 0.5
    }

    @ViewBuilder
    private func xTickLabel(_ n: Double) -> some View {
        if abs(n - 83.5) < 0.5 {
            // Title strip: sits in the gap between the "75%" label and the
            // right-aligned "100%" — tune .offset(x:) to slide it.
            Text("Elapsed")
                .font(.system(size: 9))
                .foregroundStyle(Self.tertiary)
                .offset(x: -5)
        } else if abs(n - 87.5) < 0.5 {
            // "100%" rides the label line between 75 and the right edge.
            // Centered on the 87.5 tick by default; +38 slides it right so the
            // text ends ~3pt short of the right spine — tune this offset to move it.
            Text("100%")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(Self.tertiary)
                .offset(x: 20)
        } else if abs(n) >= 0.5 {
            // 0 has no x label — the y-axis 0 marks that corner.
            Text(tickText(n))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(Self.tertiary)
        }
    }

    @ViewBuilder
    private func yTickLabel(_ n: Double) -> some View {
        if abs(n - 87.5) < 0.5 {
            // Title strip: the rotated text gets an exact 11×30 layout box, so
            // Charts anchors the visible column — left edge on the spine,
            // vertically centered on the 87.5 tick (midway 100↔75).
            Text("Used")
                .font(.system(size: 9))
                .foregroundStyle(Self.tertiary)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 11, height: 30)
                // +12pt: the y numbers carry .padding(.top, 16), which shifts their
                // visible text 8pt below their ticks — nudge lower than that midpoint.
                .offset(x: 0, y: 8)
        } else {
            // Corner "0" stays bare — the % only reads on the inner ticks.
            Text(abs(n) < 0.5 ? "0" : tickText(n))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(Self.tertiary)
                // Soft halo so ticks stay readable over corridor fills.
                .shadow(color: Color(nsColor: .windowBackgroundColor).opacity(0.55), radius: 0.75)
                .padding(.leading, 0)
                .padding(.top, 16)
        }
    }

    private func tickText(_ n: Double) -> String {
        String(Int(n.rounded())) + "%"
    }

    /// Proto tip: Elapsed line → when readings → per-series rows → over / under bands.
    private func tipView(elapsed: Double) -> some View {
        let t = elapsed / 100
        let overU = clampPct(PaceAlertBands.overUsed(atElapsed: t, thresholds: thresholds) * 100)
        let underReady = t >= thresholds.underAfterPct / 100 - 1e-9
        let underU = underReady
            ? clampPct(PaceAlertBands.underUsed(atElapsed: t, thresholds: thresholds) * 100)
            : nil as Double?
        let readings = tipWhenReadings(atElapsed: elapsed)

        return VStack(alignment: .leading, spacing: 0) {
            // Elapsed leads the tip on its own first line.
            Text("Elapsed \(Int(elapsed.rounded()))%")
                .foregroundStyle(.secondary.opacity(0.85))
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(readings.enumerated()), id: \.offset) { _, reading in
                    Text(formatWhenReading(reading))
                }
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

            ForEach(hoverDots) { dot in
                HStack(spacing: 6) {
                    tipAvatar(dot.id)
                    Text(shortName(dot.id))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.0f%% used", dot.used))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                }
                .padding(.top, 2)
            }

            // Divider between the used list and the corridor bands.
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
                .padding(.top, 6)
                .padding(.bottom, 4)

            tipBandRow(label: "Over ≥", value: String(format: "%.0f%% used", overU))
            if let underU {
                tipBandRow(label: "Under ≤", value: String(format: "%.0f%% used", underU))
            } else {
                tipBandRow(label: "Under", value: "n/a yet")
            }
        }
        .font(.system(size: 10))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 148, alignment: .leading)
        .fixedSize(horizontal: true, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .allowsHitTesting(false)
    }

    private func tipBandRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func tipAvatar(_ id: PaceHistoryMeterId) -> some View {
        let avatar: BarIcon.Avatar = id == .grok ? .grok : .cursor
        Image(nsImage: BarIcon.tintedAvatar(avatar, ink: nsColor(for: id), pointSize: 12))
            .frame(width: 12, height: 12)
    }

    private func nsColor(for id: PaceHistoryMeterId) -> NSColor {
        switch id {
        case .cursor:
            return NSColor(calibratedRed: 0x8b / 255, green: 0x5c / 255, blue: 0xf6 / 255, alpha: 1)
        case .other:
            return NSColor(calibratedRed: 0xd9 / 255, green: 0x46 / 255, blue: 0xef / 255, alpha: 1)
        case .grok:
            return NSColor(calibratedRed: 0xc0 / 255, green: 0x84 / 255, blue: 0xfc / 255, alpha: 1)
        }
    }

    private func endLabel(for id: PaceHistoryMeterId) -> String {
        switch id {
        case .cursor: return PaceHistorySeriesColor.models.endLabel
        case .other: return PaceHistorySeriesColor.other.endLabel
        case .grok: return PaceHistorySeriesColor.grok.endLabel
        }
    }

    /// Nudge Models/Other labels apart when they share nearly the same elapsed %.
    private func nameNudgeY(for id: PaceHistoryMeterId) -> CGFloat {
        guard id == .cursor || id == .other,
              let cursorEnd = series[.cursor]?.last,
              let otherEnd = series[.other]?.last,
              abs(cursorEnd.elapsedPct - otherEnd.elapsedPct) < 1.5 else { return 0 }
        switch id {
        case .cursor: return -6
        case .other: return 6
        case .grok: return 0
        }
    }

    private func tipWhenReadings(atElapsed elapsed: Double) -> [PaceHistoryTipPresentation.WhenReading] {
        var anchors: [PaceHistoryTipPresentation.BillingFamily: PaceHistoryTipPresentation.PeriodAnchor] = [:]
        for id in plottedMeterIds {
            let family = PaceHistoryTipPresentation.billingFamily(for: id)
            guard anchors[family] == nil,
                  let anchor = PaceHistoryTipPresentation.periodAnchor(from: series[id] ?? []) else {
                continue
            }
            anchors[family] = anchor
        }
        return PaceHistoryTipPresentation.whenReadings(
            elapsedPct: elapsed,
            visibleMeterIds: hoverDots.map(\.id),
            anchorsByFamily: anchors
        )
    }

    private func formatWhenReading(_ reading: PaceHistoryTipPresentation.WhenReading) -> String {
        // Compact: "26 Oct 14:32" — date and clock time joined by a space (locale formats each part).
        let day = reading.at.formatted(.dateTime.month(.abbreviated).day())
        let time = reading.at.formatted(.dateTime.hour().minute())
        let date = "\(day) \(time)"
        let ago = PaceHistoryTipPresentation.relativeAgo(from: reading.at, to: Date())
        let body = "\(date) · \(ago)"
        if let family = reading.family {
            return "\(family.tipPrefix) \(body)"
        }
        return body
    }

    private func clampPct(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private func shortName(_ id: PaceHistoryMeterId) -> String {
        switch id {
        case .cursor: return "Cursor"
        case .other: return "Other"
        case .grok: return "Grok"
        }
    }

    private func tipOffset(in size: CGSize, plotOrigin: CGFloat, elapsed: Double) -> CGSize {
        let tipW: CGFloat = 168
        let x = plotOrigin + CGFloat(
            PaceHistoryTipPresentation.tipLeadingX(
                elapsedPct: elapsed,
                plotWidth: Double(plotW),
                tipWidth: Double(tipW)
            )
        )
        let clampedX = min(max(x, 4), size.width - tipW - 4)
        return CGSize(width: clampedX, height: 8)
    }
}

#if PANEL_PREVIEW
// Canvas preview for the chart alone. Only compiled into the design-preview
// target (production never defines PANEL_PREVIEW). Use the QuotAIPanelPreview
// scheme to render it.
#Preview("Pace history chart") {
    let start = Date.now.addingTimeInterval(-25 * 24 * 3600)
    let span = 30 * 24 * 3600.0
    let cursor = (0..<12).map { step -> PaceHistorySample in
        let t = Double(step) / 11
        return PaceHistorySample(
            meterId: .cursor,
            usedPct: 72 * (0.2 + 0.8 * t),
            elapsedPct: t * 83,
            timestamp: start.addingTimeInterval(t * span * 0.83),
            periodStart: start
        )
    }
    let other = cursor.map { sample in
        PaceHistorySample(
            meterId: .other,
            usedPct: 45 * (0.2 + 0.8 * sample.elapsedPct / 83),
            elapsedPct: sample.elapsedPct,
            timestamp: sample.timestamp,
            periodStart: start
        )
    }
    let grok = cursor.map { sample in
        PaceHistorySample(
            meterId: .grok,
            usedPct: 104 * (0.2 + 0.8 * sample.elapsedPct / 83),
            elapsedPct: sample.elapsedPct,
            timestamp: sample.timestamp,
            periodStart: start
        )
    }
    PaceHistoryChart(
        thresholds: .default,
        series: [.cursor: cursor, .other: other, .grok: grok],
        showOtherModels: true
    )
    .padding()
    .frame(width: 470)
}
#endif
