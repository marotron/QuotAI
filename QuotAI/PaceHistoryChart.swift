import Charts
import SwiftUI
import QuotAICore

/// Panel pace-history plot: 2:1 used × elapsed with corridors, trajectories, and hover tip.
struct PaceHistoryChart: View {
    var thresholds: PaceAlertThresholds
    var series: [PaceHistoryMeterId: [PaceHistorySample]]
    var showOtherModels: Bool
    /// Precomputed discrepancy clusters for soft grey bands + advanced strip.
    var discrepancyClusters: [CursorDiscrepancyCluster] = []
    /// Meter-avatar filter from the panel (solo / hide / all).
    var seriesFilter: PaceHistorySeriesFilter = .all

    /// Persisted, not `@State`: the chart is remounted on every history write (`.id(paceHistoryEpoch)`),
    /// which would reset `@State`. Stores hidden layers so the empty default means "all shown".
    @AppStorage("paceHistoryHiddenLayers") private var hiddenLayersRaw = ""
    @State private var hoverElapsed: Double?
    /// Advanced disclosure only — not persisted across launches / chart remounts.
    @State private var advancedOpen = false
    @State private var stripBodyOpen = false
    @State private var selectedClusterID: String?
    @Environment(\.colorScheme) private var colorScheme

    private var hiddenLayers: Set<PaceHistoryChartLayer> {
        Set(hiddenLayersRaw.split(separator: ",").compactMap { PaceHistoryChartLayer(rawValue: String($0)) })
    }

    private var visibleLayers: Set<PaceHistoryChartLayer> {
        Set(PaceHistoryChartLayer.allCases).subtracting(hiddenLayers)
    }

    private func toggleLayer(_ layer: PaceHistoryChartLayer) {
        var hidden = hiddenLayers
        if hidden.contains(layer) {
            hidden.remove(layer)
        } else {
            hidden.insert(layer)
        }
        hiddenLayersRaw = hidden.map(\.rawValue).sorted().joined(separator: ",")
    }

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
    /// Discrepancy band / chip grey (proto `--disc`).
    private static let discColor = Color(red: 0x8e / 255, green: 0x8e / 255, blue: 0x93 / 255)
    /// Burn swatch colors from the over/under burn drawings.
    private static let burnOverField = Color(red: 0xed / 255, green: 0xe2 / 255, blue: 0xd0 / 255)
    private static let burnOverBand = Color(red: 0xf0 / 255, green: 0xaa / 255, blue: 0x55 / 255)
    private static let burnUnderField = Color(red: 0xcf / 255, green: 0xdc / 255, blue: 0xee / 255)
    private static let burnUnderBand = Color(red: 0x5b / 255, green: 0x94 / 255, blue: 0xf5 / 255)
    /// ~1.5pt min band width in elapsed-% space at `plotW`.
    private var discMinElapsedSpan: Double { Double(1.5 / plotW * 100) }

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
                // Keep Charts out of any residual layout animation on hide.
                .geometryGroup()
                .transaction { $0.animation = nil }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pace history chart, used percent versus elapsed percent")

            legend
                // Leaving the plot for the legend/… control often skips hover
                // `.ended`; clear so the dashed RuleMark does not stick on the right.
                .onHover { if $0 { hoverElapsed = nil } }

        }
    }

    private var chartBody: some View {
        Chart {
            discBandMarks
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
                let plotRect: CGRect = {
                    if let anchor = proxy.plotFrame {
                        return geo[anchor]
                    }
                    return CGRect(origin: .zero, size: geo.size)
                }()
                let plotOrigin = plotRect.origin.x
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            // Axis gutter is still inside this overlay; ignore it so
                            // exiting toward Labels / … does not park a RuleMark
                            // near the right spine.
                            guard plotRect.contains(location) else {
                                hoverElapsed = nil
                                return
                            }
                            let localX = location.x - plotOrigin
                            if let elapsed: Double = proxy.value(atX: localX) {
                                hoverElapsed = min(max(elapsed, 0), 100)
                            }
                        case .ended:
                            hoverElapsed = nil
                        }
                    }
                    .onTapGesture { location in
                        guard plotRect.contains(location) else { return }
                        let localX = location.x - plotOrigin
                        guard let elapsed: Double = proxy.value(atX: localX) else { return }
                        selectCluster(atElapsed: min(max(elapsed, 0), 100))
                    }
                    .overlay(alignment: .topLeading) {
                        if let hoverElapsed, !hoverDots.isEmpty {
                            tipView(elapsed: hoverElapsed)
                                .offset(
                                    tipOffset(
                                        in: geo.size,
                                        plotOrigin: plotOrigin,
                                        elapsed: hoverElapsed,
                                        includesDisc: hoverDiscCluster(at: hoverElapsed) != nil
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
    private var discBandMarks: some ChartContent {
        if visibleLayers.contains(.disc) {
            ForEach(discrepancyClusters) { cluster in
                let span = paintedDiscSpan(for: cluster)
                let active = cluster.id == resolvedSelectedClusterID
                RectangleMark(
                    xStart: .value("DiscStart", span.lo),
                    xEnd: .value("DiscEnd", span.hi),
                    yStart: .value("Bottom", 0.0),
                    yEnd: .value("Top", 100.0)
                )
                .foregroundStyle(Self.discColor.opacity(active ? 0.26 : 0.14))
            }
        }
    }

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
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    y: .value("Used", pt.usedPct),
                    series: .value("Layer", "Over")
                )
                .foregroundStyle(Self.overFill)
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3.5, 2.5]))
                .interpolationMethod(.monotone)
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
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Elapsed", pt.elapsedPct),
                    y: .value("Used", pt.usedPct),
                    series: .value("Layer", "Under")
                )
                .foregroundStyle(Self.underFill)
                .lineStyle(StrokeStyle(lineWidth: 0.7, dash: [3.5, 2.5]))
                .interpolationMethod(.monotone)
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
                .interpolationMethod(.monotone)
            }
        }
    }

    @ChartContentBuilder
    private var seriesMarks: some ChartContent {
        // One downsampled LineMark stream per meter (series tag). Hover/tip still
        // use the full-resolution series so accuracy is unchanged.
        ForEach(plottedMeterIds, id: \.rawValue) { meterId in
            ForEach(downsampledSeriesPoints(for: meterId)) { row in
                LineMark(
                    x: .value("Elapsed", row.elapsedPct),
                    y: .value("Used", row.usedPct),
                    series: .value("Meter", meterId.rawValue)
                )
                .foregroundStyle(color(for: meterId))
                .opacity(0.75)
                .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }
        }

        ForEach(seriesEndPoints) { end in
            // Current tip: halo + core.
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
                HStack(spacing: 2) {
                    if visibleLayers.contains(.icons) {
                        // Other has no dedicated avatar asset — reuse the Cursor
                        // avatar inked in the Other fuchsia, matching the meter row.
                        Image(nsImage: BarIcon.tintedAvatar(
                            end.meterId == .grok ? .grok : .cursor,
                            ink: nsColor(for: end.meterId),
                            pointSize: 10
                        ))
                        .frame(width: 10, height: 10)
                    }
                    if visibleLayers.contains(.names) {
                        Text(endLabel(for: end.meterId))
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(color(for: end.meterId))
                            .shadow(color: Color(nsColor: .windowBackgroundColor).opacity(0.7), radius: 1.2)
                    }
                }
                .offset(y: nameNudgeY(for: end.meterId))
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

    /// Primary row matches v0.18; advanced opens a second row for the Discrepancies chip.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    corridorGroup
                    Spacer(minLength: 4)
                    legendTrailing
                }
                VStack(alignment: .leading, spacing: 6) {
                    corridorGroup
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        legendTrailing
                    }
                }
            }

        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Chart layer filters")
    }

    private var legendTrailing: some View {
        HStack(spacing: 6) {
            visibilityGroup
            advancedToggle
        }
    }

    private var corridorGroup: some View {
        chipGroup {
            legendChip(.over, title: "Over burn") {
                burnSwatch(over: true)
            }
            chipDivider
            legendChip(.under, title: "Under burn") {
                burnSwatch(over: false)
            }
            chipDivider
            legendChip(.even, title: "Ideal pace") {
                // Discrete capsules match Over/Under swatches — stroked dashes alias badly at 1pt.
                HStack(spacing: 1.5) {
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                    Capsule().fill(Self.evenColor).frame(width: 2.5, height: 1.5)
                }
                .frame(width: 12, height: 8)
            }
        }
    }

    private var visibilityGroup: some View {
        chipGroup {
            legendChip(.names, title: "Labels") {
                EmptyView()
            }
            chipDivider
            legendChip(.icons, title: "Icons") {
                EmptyView()
            }
        }
    }

    private var advancedToggle: some View {
        let count = discrepancyClusters.reduce(0) { $0 + $1.events.count }
        return Button {
            setAdvancedOpen(!advancedOpen)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .light))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(advancedOpen ? Color.primary.opacity(0.06) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(advancedOpen ? "Hide advanced" : "Advanced")
        .accessibilityLabel(
            advancedOpen
                ? "Advanced, \(count) discrepancies"
                : "Show advanced, \(count) discrepancies"
        )
        .accessibilityAddTraits(advancedOpen ? .isSelected : [])
        .popover(isPresented: $advancedOpen, arrowEdge: .bottom) {
            advancedPopover
        }
    }

    private var advancedPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipGroup {
                legendChip(.disc, title: "Discrepancies") {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Self.discColor.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .strokeBorder(Self.discColor.opacity(0.55), lineWidth: 0.5)
                        )
                        .frame(width: 8, height: 10)
                }
            }

            discrepancyStrip
                .onHover { if $0 { hoverElapsed = nil } }
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        // Width matches the chart; height hugs content so collapse/expand
        // does not leave empty popover chrome (safe — this is not MenuBarExtra).
        .frame(width: plotW, alignment: .topLeading)
        .padding(12)
    }

    /// Mini bar for the burn chips: tinted field with a band along the bottom (over) or top (under) edge.
    private func burnSwatch(over: Bool) -> some View {
        Canvas { context, size in
            let field = over ? Self.burnOverField : Self.burnUnderField
            let band = over ? Self.burnOverBand : Self.burnUnderBand
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(field))
            // Band thickness matches the exact-pace dashes (1.5pt).
            let bandH: CGFloat = 1.5
            let bandY = over ? size.height - bandH : 0
            // Three blocks: short left, long centre, short right (proportions from the burn drawings).
            for (x0, x1) in [(0.0, 0.083), (0.29, 0.708), (0.917, 1.0)] {
                let rect = CGRect(
                    x: size.width * x0,
                    y: bandY,
                    width: size.width * (x1 - x0),
                    height: bandH
                )
                context.fill(Path(rect), with: .color(band))
            }
        }
        .frame(width: 12, height: 8)
    }

    /// Hairline between chips inside a group; short (inset from the group edges) like toolbar separators.
    private var chipDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 1, height: 10)
    }

    /// Shared container so related chips read as one control.
    private func chipGroup<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 0) {
            content()
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private func legendChip<Swatch: View>(
        _ layer: PaceHistoryChartLayer,
        title: String,
        @ViewBuilder swatch: () -> Swatch
    ) -> some View {
        let on = visibleLayers.contains(layer)
        return Button {
            toggleLayer(layer)
        } label: {
            HStack(spacing: 4) {
                swatch()
                Text(title)
                    .strikethrough(!on)
            }
            .padding(.leading, 5)
            .padding(.trailing, 7)
            .padding(.vertical, 2)
            .opacity(on ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityLabel(title)
        .accessibilityValue(on ? "Shown" : "Hidden")
    }

    // MARK: - Discrepancy strip

    private var discrepancyStrip: some View {
        let cluster = selectedCluster
        let idx = selectedClusterIndex
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                stripBodyOpen.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("\(cluster.events.count)")
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(Self.discColor.opacity(0.18))
                        )
                    (
                        Text("Discrepancies").fontWeight(.semibold)
                            + Text(" · \(clusterPeriodRangeLabel(cluster))")
                    )
                    .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(
                        "\(Int(cluster.elapsedLo.rounded()))–\(Int(cluster.elapsedHi.rounded()))% elapsed"
                    )
                    .foregroundStyle(Self.tertiary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(stripBodyOpen ? 90 : 0))
                        .foregroundStyle(Self.tertiary)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Discrepancy cluster details")

            if stripBodyOpen {
                HStack(spacing: 8) {
                    Button("←") { stepCluster(by: -1) }
                        .buttonStyle(.plain)
                    Text("Cluster \(idx + 1) of \(discrepancyClusters.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button("→") { stepCluster(by: 1) }
                        .buttonStyle(.plain)
                    Spacer(minLength: 0)
                    Text(kindMixLabel(for: cluster))
                        .font(.system(size: 11))
                        .foregroundStyle(Self.tertiary)
                }
                .padding(.top, 6)

                // ScrollView + maxHeight alone often collapses to 0 in a VStack; pin an
                // explicit height capped at discEventListMaxHeight so rows stay visible.
                // LazyVStack keeps large clusters (100+) from laying out every row up front.
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(cluster.events.enumerated()), id: \.offset) { offset, event in
                            if offset > 0 {
                                Divider().opacity(0.35)
                            }
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(meterDotColor(event.meter))
                                    .frame(width: 6, height: 6)
                                Text("\(kindLabel(event.kind)) · \(meterLabel(event.meter))")
                                    .lineLimit(1)
                                Text(event.displayModelLabel)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(discEventTimeLabel(event.timestamp))
                                    .foregroundStyle(Self.tertiary)
                                    .monospacedDigit()
                            }
                            .font(.system(size: 11))
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: discEventListHeight(for: cluster.events.count))
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedCluster: CursorDiscrepancyCluster {
        if let id = resolvedSelectedClusterID,
           let match = discrepancyClusters.first(where: { $0.id == id }) {
            return match
        }
        return discrepancyClusters[0]
    }

    private var selectedClusterIndex: Int {
        discrepancyClusters.firstIndex(where: { $0.id == selectedCluster.id }) ?? 0
    }

    private var resolvedSelectedClusterID: String? {
        if let selectedClusterID,
           discrepancyClusters.contains(where: { $0.id == selectedClusterID }) {
            return selectedClusterID
        }
        return discrepancyClusters.first?.id
    }

    private func paintedDiscSpan(for cluster: CursorDiscrepancyCluster) -> (lo: Double, hi: Double) {
        let lo = cluster.elapsedLo
        let hi = max(cluster.elapsedHi, lo + discMinElapsedSpan)
        return (lo, min(hi, 100))
    }

    /// Advanced content lives in a separate content-sized popover, so this
    /// state change never resizes the MenuBarExtra panel.
    private func setAdvancedOpen(_ open: Bool) {
        hoverElapsed = nil
        advancedOpen = open
        if !open {
            stripBodyOpen = false
        } else if selectedClusterID == nil {
            selectedClusterID = discrepancyClusters.first?.id
        }
    }

    private func selectCluster(atElapsed elapsed: Double) {
        guard let cluster = hoverDiscCluster(at: elapsed) else { return }
        hoverElapsed = nil
        selectedClusterID = cluster.id
        advancedOpen = true
        stripBodyOpen = true
    }

    /// Cluster under the cursor when the Discrepancies layer is visible.
    private func hoverDiscCluster(at elapsed: Double) -> CursorDiscrepancyCluster? {
        guard visibleLayers.contains(.disc) else { return nil }
        let pad = 0.4
        return discrepancyClusters.first(where: {
            let span = paintedDiscSpan(for: $0)
            return elapsed >= span.lo - pad && elapsed <= span.hi + pad
        })
    }

    private func stepCluster(by delta: Int) {
        guard !discrepancyClusters.isEmpty else { return }
        let next = (selectedClusterIndex + delta + discrepancyClusters.count) % discrepancyClusters.count
        selectedClusterID = discrepancyClusters[next].id
        stripBodyOpen = true
    }

    /// First→last event clock span for the strip title (no "this period" / density labels).
    private func clusterPeriodRangeLabel(_ cluster: CursorDiscrepancyCluster) -> String {
        guard let first = cluster.events.map(\.timestamp).min(),
              let last = cluster.events.map(\.timestamp).max() else {
            return "—"
        }
        let firstDay = first.formatted(.dateTime.month(.abbreviated).day())
        let lastDay = last.formatted(.dateTime.month(.abbreviated).day())
        let firstTime = first.formatted(.dateTime.hour().minute())
        let lastTime = last.formatted(.dateTime.hour().minute())
        if Calendar.current.isDate(first, inSameDayAs: last) {
            if firstTime == lastTime {
                return "\(firstDay) \(firstTime)"
            }
            return "\(firstDay) \(firstTime)–\(lastTime)"
        }
        return "\(firstDay) \(firstTime) – \(lastDay) \(lastTime)"
    }

    private func discEventTimeLabel(_ date: Date) -> String {
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        let time = date.formatted(.dateTime.hour().minute())
        return "\(day) \(time)"
    }

    private func kindLabel(_ kind: CursorDiscrepancyEvent.Kind) -> String {
        switch kind {
        case .unbilledActivity: return "Unbilled"
        case .unattributedQuotaChange: return "Unattributed"
        }
    }

    private func meterLabel(_ meter: CursorMeterClassification) -> String {
        switch meter {
        case .cursorModels: return "Cursor Models"
        case .otherModels: return "Other Models"
        }
    }

    private func meterDotColor(_ meter: CursorMeterClassification) -> Color {
        switch meter {
        case .cursorModels: return Self.cursorColor
        case .otherModels: return Self.otherColor
        }
    }

    private func kindMixLabel(for cluster: CursorDiscrepancyCluster) -> String {
        var counts: [CursorDiscrepancyEvent.Kind: Int] = [:]
        for event in cluster.events {
            counts[event.kind, default: 0] += 1
        }
        return CursorDiscrepancyEvent.Kind.allCases.compactMap { kind in
            guard let n = counts[kind], n > 0 else { return nil }
            return "\(n) \(kindLabel(kind))"
        }.joined(separator: " · ")
    }

    private static let discEventListMaxHeight: CGFloat = 120
    private static let discEventRowHeight: CGFloat = 26

    private func discEventListHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return min(Self.discEventListMaxHeight, CGFloat(count) * Self.discEventRowHeight)
    }

    // MARK: - Data

    private var plottedMeterIds: [PaceHistoryMeterId] {
        var ids: [PaceHistoryMeterId] = [.cursor, .grok]
        if showOtherModels { ids.insert(.other, at: 1) }
        return ids.filter { !(series[$0] ?? []).isEmpty && seriesFilter.isVisible($0) }
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

    private func downsampledSeriesPoints(for meterId: PaceHistoryMeterId) -> [SeriesPoint] {
        PaceHistoryChartDownsample.downsample(samples: series[meterId] ?? [])
            .enumerated()
            .map { idx, sample in
                SeriesPoint(
                    index: idx,
                    meterId: meterId,
                    elapsedPct: sample.elapsedPct,
                    usedPct: sample.usedPct
                )
            }
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

    /// Proto tip: Elapsed line → when readings → per-series rows → disc (if any) → over / under.
    private func tipView(elapsed: Double) -> some View {
        let t = elapsed / 100
        let overU = clampPct(PaceAlertBands.overUsed(atElapsed: t, thresholds: thresholds) * 100)
        let underReady = t >= thresholds.underAfterPct / 100 - 1e-9
        let underU = underReady
            ? clampPct(PaceAlertBands.underUsed(atElapsed: t, thresholds: thresholds) * 100)
            : nil as Double?
        let readings = tipWhenReadings(atElapsed: elapsed)
        let discCluster = hoverDiscCluster(at: elapsed)

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
                    if visibleLayers.contains(.icons) {
                        tipAvatar(dot.id)
                    }
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

            if let discCluster {
                tipDiscSection(discCluster, atElapsed: elapsed)
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

    @ViewBuilder
    private func tipDiscSection(_ cluster: CursorDiscrepancyCluster, atElapsed elapsed: Double) -> some View {
        let events = tipDiscEvents(in: cluster, atElapsed: elapsed)
        if !events.isEmpty {
            Rectangle()
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 1)
                .padding(.top, 6)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                    Text(shortDiscEventLine(event))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    /// Closest event in the cluster to the hover clock, plus its in-cluster neighbors (1–3 rows).
    private func tipDiscEvents(
        in cluster: CursorDiscrepancyCluster,
        atElapsed elapsed: Double
    ) -> [CursorDiscrepancyEvent] {
        let ordered = cluster.events.sorted { $0.timestamp < $1.timestamp }
        guard !ordered.isEmpty else { return [] }

        let pivotIndex: Int = {
            guard let at = tipDateForDiscMatch(atElapsed: elapsed) else { return 0 }
            var best = 0
            var bestDelta = abs(ordered[0].timestamp.timeIntervalSince(at))
            for i in ordered.indices.dropFirst() {
                let delta = abs(ordered[i].timestamp.timeIntervalSince(at))
                if delta < bestDelta {
                    best = i
                    bestDelta = delta
                }
            }
            return best
        }()

        var picked: [CursorDiscrepancyEvent] = []
        if pivotIndex > 0 {
            picked.append(ordered[pivotIndex - 1])
        }
        picked.append(ordered[pivotIndex])
        if pivotIndex + 1 < ordered.count {
            picked.append(ordered[pivotIndex + 1])
        }
        return picked
    }

    private func tipDateForDiscMatch(atElapsed elapsed: Double) -> Date? {
        // Prefer Cursor billing window — discrepancy meters live there.
        tipWhenReadings(atElapsed: elapsed)
            .first(where: { $0.family == nil || $0.family == .cursor })?
            .at
            ?? tipWhenReadings(atElapsed: elapsed).first?.at
    }

    /// Strip-style row, compressed for the tip: `unbilled · other claude-4.5-sonnet 09:18`.
    private func shortDiscEventLine(_ event: CursorDiscrepancyEvent) -> String {
        let kind: String = {
            switch event.kind {
            case .unbilledActivity: return "unbilled"
            case .unattributedQuotaChange: return "unattributed"
            }
        }()
        let meter: String = {
            switch event.meter {
            case .cursorModels: return "cursor"
            case .otherModels: return "other"
            }
        }()
        let models = event.displayModelLabel
        let time = event.timestamp.formatted(.dateTime.hour().minute())
        if models == "—" {
            return "\(kind) · \(meter) \(time)"
        }
        return "\(kind) · \(meter) \(models) \(time)"
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

    private func tipOffset(
        in size: CGSize,
        plotOrigin: CGFloat,
        elapsed: Double,
        includesDisc: Bool
    ) -> CGSize {
        let tipW: CGFloat = includesDisc ? 210 : 168
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
