import AppKit
import SwiftUI
import QuotAICore

/// MenuBarExtra `.window` content: status, meters, pace history chart, actions.
struct MenuBarWindowPanel: View {
    @ObservedObject var store: QuotaStore
    var showOtherModels: Bool
    var corridorAlertsEnabled: Bool
    /// Cursor Models + Other corridor (also painted on menu pace history this PR).
    var cursorThresholds: PaceAlertThresholds
    var grokThresholds: PaceAlertThresholds

    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("menuPinDensity") private var menuPinDensity: MenuPinDensity = .compact
    /// Meter-avatar chart filter (solo → hide → all). Lives on the panel so chart remounts keep it.
    @State private var seriesFilter = PaceHistorySeriesFilter.all
    /// Pace chart X zoom (elapsed %). Session state — survives history remounts; clears with the panel.
    @State private var paceChartXDomain: ClosedRange<Double> = PaceHistoryChartZoom.fullDomain
    #if DEBUG
    @State private var menuOpenStart: Date?
    #endif

    private var now: Date { store.displayClock }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusRow
                .padding(.horizontal, 5)

            if let notice = store.authError ?? store.refreshError {
                Text(notice)
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 19)
                    .padding(.vertical, 2)
            }

            panelSeparator

            metersGrid
                .padding(.horizontal, 5)

            chartWell
                .padding(.top, 4)
                .padding(.bottom, 6)
                .padding(.horizontal, 14)

            if store.discrepancyDetectionEnabled,
               let event = store.cursorDiscrepancyEvents.last {
                discrepancyWarning(event)
                    .padding(.horizontal, 19)
                    .padding(.bottom, 6)
            }

            MenuPinsView(store: store)

            panelSeparator

            settingsAndAboutRows
                .padding(.horizontal, 5)

            panelSeparator

            actionRow("Quit QuotAI", shortcut: "⌘Q") {
                #if !PANEL_PREVIEW
                    NSApplication.shared.terminate(nil)
                #endif
            }
            #if !PANEL_PREVIEW
                .keyboardShortcut("q", modifiers: .command)
            #endif
            .padding(.horizontal, 5)
        }
        .padding(.vertical, 5)
        .frame(width: 470)
        .environment(\.menuRowMetrics, MenuRowMetrics(density: menuPinDensity))
        .background(panelBackground)
        .onAppear {
            #if DEBUG
            menuOpenStart = Date()
            #endif
            store.snapDisplayClock()
            Task { await store.refreshIfStale() }
        }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 0) {
                    Text("Last refresh: ")
                    // Avatars inked in the row text color so they read as part of the line.
                    Image(nsImage: BarIcon.tintedAvatar(
                        .cursor,
                        ink: NSColor(secondaryText),
                        pointSize: 11
                    ))
                    .frame(width: 11, height: 11)
                    Text(" Cursor ")
                    Text(timeText(store.lastCursorRefreshed))
                        .monospacedDigit()
                    if let cursor = store.lastCursorRefreshed {
                        FreshnessBadgeView(
                            lastAt: cursor,
                            now: context.date,
                            interval: store.pollIntervalSeconds(for: .cursor, now: context.date),
                            isSpinning: store.isRefreshingFamily(.cursor),
                            accessibilityName: "Cursor"
                        ) {
                            Task { await store.refresh(.cursor) }
                        }
                    }
                    Text(" · ")
                    Image(nsImage: BarIcon.tintedAvatar(
                        .grok,
                        ink: NSColor(secondaryText),
                        pointSize: 11
                    ))
                    .frame(width: 11, height: 11)
                    Text(" Grok ")
                    Text(timeText(store.lastGrokRefreshed))
                        .monospacedDigit()
                    if let grok = store.lastGrokRefreshed {
                        FreshnessBadgeView(
                            lastAt: grok,
                            now: context.date,
                            interval: store.pollIntervalSeconds(for: .grok, now: context.date),
                            isSpinning: store.isRefreshingFamily(.grok),
                            accessibilityName: "Grok Bot"
                        ) {
                            Task { await store.refresh(.grok) }
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            VersionChangelogButton(idleForeground: secondaryText)
        }
        .font(.system(size: 11))
        .foregroundStyle(secondaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
        .frame(minHeight: 20)
    }

    // MARK: - Meters

    /// Avatar + name left; formula metrics (used → reset) flush right.
    private var metersGrid: some View {
        VStack(alignment: .leading, spacing: 2) {
            meterRow(
                title: "Cursor Models",
                meter: store.cursorModels.projected(at: now),
                avatar: .cursor,
                series: .models,
                meterId: .cursor
            )
            if showOtherModels {
                meterRow(
                    title: "Other Models",
                    meter: store.otherModels.projected(at: now),
                    avatar: .cursor,
                    series: .other,
                    meterId: .other
                )
            }
            meterRow(
                title: "Grok Bot",
                meter: store.grokBot.projected(at: now),
                avatar: .grok,
                series: .grok,
                meterId: .grok
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quota meters")
    }

    @ViewBuilder
    private func meterRow(
        title: String,
        meter: QuotaMeter,
        avatar: BarIcon.Avatar,
        series: PaceHistorySeriesColor,
        meterId: PaceHistoryMeterId
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            seriesAvatarButton(avatar, series: series, meterId: meterId)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(primaryText)
                .lineLimit(1)
                // Never squeeze the meter name into "Cursor Mod…" — the metric
                // cluster below absorbs row pressure instead.
                .fixedSize()

            if meter.isUnavailable {
                Text("unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                Spacer(minLength: 8)
            } else {
                // Fixed trailing columns so used / elapsed / pace / reset line up
                // across rows; maxWidth:.infinity keeps the cluster flush right
                // regardless of title width (a collapsed Spacer used to drift it).
                HStack(spacing: 4) {
                    fact(icon: "sparkles", value: usedText(meter))
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                        .help(usedHelp(meter))
                    op("÷")
                    fact(icon: "hourglass.bottomhalf.filled", value: elapsedText(meter))
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                        .help(elapsedHelp(meter))
                    op("=")
                    paceFact(meter)
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                        .help(paceHelp(meter))
                    alertSlot(for: meter)
                    op("→")
                    fact(icon: "timer", value: resetText(meter))
                        .frame(width: Self.resetColumnWidth, alignment: .trailing)
                        .help(resetHelp(meter))
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(minHeight: 20)
    }

    private static let pctColumnWidth: CGFloat = 46
    private static let resetColumnWidth: CGFloat = 98

    private func seriesAvatarButton(
        _ avatar: BarIcon.Avatar,
        series: PaceHistorySeriesColor,
        meterId: PaceHistoryMeterId
    ) -> some View {
        let cycle = seriesFilter.avatarCycle(for: meterId)
        let ink = Self.nsColor(hex: series.hex)
        return Button {
            seriesFilter = seriesFilter.cycling(tapped: meterId)
        } label: {
            Image(nsImage: BarIcon.tintedAvatar(avatar, ink: ink, pointSize: 14))
                .frame(width: 14, height: 14)
                .opacity(cycle == .dim || cycle == .hide ? 0.32 : 1)
                .saturation(cycle == .hide ? 0.65 : 1)
                .overlay {
                    if cycle == .solo {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color(nsColor: ink).opacity(0.55), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(seriesFilterHelp(cycle: cycle))
        .accessibilityLabel("\(titleForMeter(meterId)) chart filter")
        .accessibilityValue(seriesFilterAccessibilityValue(cycle: cycle, meterId: meterId))
        .accessibilityHint("Cycles chart: solo, hide, all")
    }

    private func titleForMeter(_ id: PaceHistoryMeterId) -> String {
        switch id {
        case .cursor: return "Cursor Models"
        case .other: return "Other Models"
        case .grok: return "Grok Bot"
        }
    }

    private func seriesFilterHelp(cycle: PaceHistorySeriesAvatarCycle) -> String {
        switch cycle {
        case .solo: return "Chart: showing only this · click to hide"
        case .hide: return "Chart: hidden · click to show all"
        case .dim, .all: return "Chart: solo → hide → all"
        }
    }

    private func seriesFilterAccessibilityValue(
        cycle: PaceHistorySeriesAvatarCycle,
        meterId: PaceHistoryMeterId
    ) -> String {
        switch seriesFilter.mode {
        case .all:
            return "all series"
        case .solo:
            return cycle == .solo ? "solo" : "dimmed"
        case .hide:
            return seriesFilter.focus == meterId ? "hidden" : "shown"
        }
    }

    private static func nsColor(hex: String) -> NSColor {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let n = UInt32(h, radix: 16) else {
            return NSColor.secondaryLabelColor
        }
        return NSColor(
            calibratedRed: CGFloat((n >> 16) & 0xff) / 255,
            green: CGFloat((n >> 8) & 0xff) / 255,
            blue: CGFloat(n & 0xff) / 255,
            alpha: 1
        )
    }

    private func alertSlot(for meter: QuotaMeter) -> some View {
        let kind = alertKind(for: meter)
        let symbol = PaceMeterPresentation.alertSymbolName(kind: kind)
        let tint = PaceMeterPresentation.alertTint(kind: kind)
        return Image(systemName: symbol)
            .font(.system(size: 12))
            .foregroundStyle(alertColor(tint))
            .frame(width: 14, height: 14)
            .accessibilityLabel(alertAccessibility(kind))
    }

    private func fact(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(secondaryText.opacity(0.9))
                .frame(width: 11, height: 11)
            Text(value)
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(secondaryText)
        }
    }

    private func paceFact(_ meter: QuotaMeter) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 10))
                .foregroundStyle(secondaryText.opacity(0.9))
                .frame(width: 11, height: 11)
            Text(paceLabel(meter))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(secondaryText)
        }
    }

    private func op(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color(red: 0x8e / 255, green: 0x8e / 255, blue: 0x93 / 255))
            .frame(minWidth: 9)
    }

    // MARK: - Chart well

    private var chartWell: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaceHistoryChart(
                cursorThresholds: cursorThresholds,
                grokThresholds: grokThresholds,
                series: historySeries,
                showOtherModels: showOtherModels,
                discrepancyClusters: discrepancyClustersForChart,
                seriesFilter: seriesFilter,
                xDomain: $paceChartXDomain
            )
            .id(store.paceHistoryEpoch)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(divider.opacity(0.8), lineWidth: 0.5)
                )
        )
        // Zoomed corridor AreaMarks spill into this well’s padding — keep the
        // spill as context, but wash it out so only the plot box stays vivid.
        .overlay {
            if PaceHistoryChartZoom.isZoomed(paceChartXDomain) {
                zoomSpillMuteVeil
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        #if DEBUG
        // A GeometryReader is laid out with the chart well, so this records the
        // first panel layout after the menu's `onAppear` timestamp.
        .background {
            GeometryReader { _ in
                Color.clear
                    .onChange(of: menuOpenStart, initial: true) { _, start in
                        guard let start else { return }
                        let elapsed = Date().timeIntervalSince(start) * 1_000
                        print(
                            String(
                                format: "QuotAI menu panel first layout: %.1f ms",
                                elapsed
                            )
                        )
                        menuOpenStart = nil
                    }
            }
        }
        #endif
    }

    /// Semi-transparent wash over the well padding (outside the plot box).
    /// Plot stays clear; spilled over/under fills read as muted context.
    /// Height includes the x-axis gutter — under-burn often stubs into the
    /// bottom-right pad below the plot floor.
    private var zoomSpillMuteVeil: some View {
        // Match PaceHistoryChart: plotW 414, plotH 207, axisPadBottom 22, well pad 14.
        let pad: CGFloat = 14
        let plotH: CGFloat = 414 / 2
        let axisPadBottom: CGFloat = 22
        let veilH = plotH + axisPadBottom
        return GeometryReader { geo in
            let veil = Color(nsColor: .windowBackgroundColor).opacity(0.62)
            ZStack(alignment: .topLeading) {
                veil
                    .frame(width: pad, height: veilH)
                    .offset(x: 0, y: pad)
                veil
                    .frame(width: pad, height: veilH)
                    .offset(x: geo.size.width - pad, y: pad)
            }
        }
        .allowsHitTesting(false)
    }

    private var historySeries: [PaceHistoryMeterId: [PaceHistorySample]] {
        _ = store.paceHistoryEpoch
        var map: [PaceHistoryMeterId: [PaceHistorySample]] = [:]
        for id in PaceHistoryMeterId.allCases {
            map[id] = store.paceHistoryStore.series(for: id)
        }
        return map
    }

    private var discrepancyClustersForChart: [CursorDiscrepancyCluster] {
        guard store.discrepancyDetectionEnabled,
              let start = store.cursorModels.periodStart ?? store.otherModels.periodStart,
              let end = store.cursorModels.periodEnd ?? store.otherModels.periodEnd
        else {
            return []
        }
        return CursorDiscrepancyClusterer.cluster(
            events: store.cursorDiscrepancyEvents,
            periodStart: start,
            periodEnd: end
        )
    }

    private func discrepancyWarning(_ event: CursorDiscrepancyEvent) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Cursor usage discrepancy")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(discrepancyWhen(for: event))
                        .font(.system(size: 11))
                        .foregroundStyle(secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                Text(discrepancyText(for: event))
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Cursor usage discrepancy. \(discrepancyWhen(for: event)). \(discrepancyText(for: event))"
        )
    }

    private func discrepancyWhen(for event: CursorDiscrepancyEvent) -> String {
        event.timestamp.formatted(
            .dateTime.day().month(.abbreviated).year().hour().minute()
        )
    }

    private func discrepancyText(for event: CursorDiscrepancyEvent) -> String {
        let meter = event.meter == .cursorModels ? "Cursor Models" : "Other Models"
        let direction: String
        switch event.kind {
        case .unbilledActivity:
            direction = "\(meter): activity was not reflected in the meter"
        case .unattributedQuotaChange:
            direction = "\(meter): meter increased without local activity"
        }
        let models = event.displayModelLabel
        let modelsSuffix = models == "—" ? "" : " · \(models)"
        return "\(direction)\(modelsSuffix)"
    }

    // MARK: - Actions

    private func actionRow(_ title: String, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
        PanelActionRow(title: title, shortcut: shortcut, action: action)
    }

    @ViewBuilder
    private var settingsRow: some View {
        actionRow("Settings…", shortcut: "⌘,") {
            #if !PANEL_PREVIEW
                SettingsWindowElevator.show { openSettings() }
            #endif
        }
        #if !PANEL_PREVIEW
            .keyboardShortcut(",", modifiers: .command)
        #endif
    }

    @ViewBuilder
    private var aboutRow: some View {
        actionRow("About") {
            #if !PANEL_PREVIEW
                AboutWindowHost.shared.showAbout()
            #endif
        }
    }

    /// Compact: Settings and About share one line, split by the same gutter and divider as the pinned columns.
    /// Normal: one row each.
    @ViewBuilder
    private var settingsAndAboutRows: some View {
        if MenuRowMetrics(density: menuPinDensity).columns > 1 {
            HStack(spacing: 0) {
                settingsRow
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 6)
                aboutRow
                    .frame(maxWidth: .infinity)
                    .padding(.leading, 6)
            }
            .overlay(alignment: .center) {
                PanelColumnDivider()
            }
        } else {
            settingsRow
            aboutRow
        }
    }

    private var panelSeparator: some View {
        PanelRule()
    }

    // MARK: - Copy helpers

    private func usedText(_ meter: QuotaMeter) -> String {
        guard let pct = meter.percentUsed else { return "—" }
        return QuotaPercent.format(pct)
    }

    private func elapsedText(_ meter: QuotaMeter) -> String {
        guard let elapsed = meter.periodElapsedPercent(now: now) else { return "—" }
        return QuotaPercent.format(elapsed)
    }

    private func resetText(_ meter: QuotaMeter) -> String {
        guard let seconds = meter.secondsRemaining(at: now) else { return "—" }
        return RemainingTime.formatDetailed(seconds: seconds) + " left"
    }

    private func paceLabel(_ meter: QuotaMeter) -> String {
        let exhausted = meter.pace?.daysToExhaustion == 0 || (meter.percentUsed ?? 0) >= 100
        return PaceMeterPresentation.pacePercentText(ratio: meter.pace?.ratio, exhausted: exhausted)
    }

    // MARK: - Hover tooltips (meter-row fact columns)

    /// `Used quota: 72.34%`
    private func usedHelp(_ meter: QuotaMeter) -> String {
        guard let pct = meter.percentUsed else { return "Used quota" }
        return "Used quota: \(String(format: "%.2f", pct))%"
    }

    /// `Elapsed billing period: 24d 21h of 30d → 79.17%`
    private func elapsedHelp(_ meter: QuotaMeter) -> String {
        guard let start = meter.periodStart, let end = meter.periodEnd,
              end.timeIntervalSince(start) > 0 else {
            return "Elapsed share of the billing period"
        }
        let total = end.timeIntervalSince(start)
        let gone = max(0, now.timeIntervalSince(start))
        let base = "Elapsed billing period: "
            + "\(RemainingTime.formatDetailed(seconds: gone)) of \(RemainingTime.formatDetailed(seconds: total))"
        guard let pct = meter.periodElapsedPercent(now: now) else { return base }
        return base + " → \(String(format: "%.2f", pct))%"
    }

    /// `Pace (used ÷ elapsed): 86.12%`
    private func paceHelp(_ meter: QuotaMeter) -> String {
        guard let ratio = meter.pace?.ratio else { return "Pace: used ÷ elapsed" }
        return "Pace (used ÷ elapsed): \(String(format: "%.2f", ratio * 100))%"
    }

    /// `Quota resets: 7 Nov 14:32` (absolute date when the period end is known)
    private func resetHelp(_ meter: QuotaMeter) -> String {
        if let end = meter.periodEnd {
            let day = end.formatted(.dateTime.month(.abbreviated).day())
            let time = end.formatted(.dateTime.hour().minute())
            return "Quota resets: \(day) \(time)"
        }
        guard let seconds = meter.secondsRemaining(at: now) else { return "Time until quota reset" }
        return "Time until quota reset: \(RemainingTime.formatDetailed(seconds: seconds))"
    }

    private func alertKind(for meter: QuotaMeter) -> PaceAlertKind {
        guard corridorAlertsEnabled, !meter.isUnavailable else { return .quiet }
        if let pct = meter.percentUsed,
           let start = meter.periodStart,
           let end = meter.periodEnd,
           let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end, now: now) {
            let thresholds = PaceAlertFamily.resolve(meterName: meter.name) == .grok
                ? grokThresholds
                : cursorThresholds
            return PaceAlertBands.evaluate(
                percentUsed: pct,
                elapsedFraction: t,
                thresholds: thresholds,
                smart: true
            )
        }
        if (meter.percentUsed ?? 0) >= 100 { return .exhausted }
        return .quiet
    }

    private func alertColor(_ tint: SymbolTint) -> Color {
        switch tint {
        case .under: return Color(red: 0x0a / 255, green: 0x84 / 255, blue: 1)
        case .warning: return Color(red: 1, green: 0x9f / 255, blue: 0x0a / 255)
        case .critical: return Color(red: 1, green: 0x45 / 255, blue: 0x3a / 255)
        case .neutral, .ok: return secondaryText.opacity(0.45)
        }
    }

    private func alertAccessibility(_ kind: PaceAlertKind) -> String {
        switch kind {
        case .under: return "Under corridor"
        case .over: return "Over corridor"
        case .exhausted: return "Exhausted"
        case .quiet: return "On corridor"
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return LastRefreshStatus.format24Hour(date)
    }

    static func relativeAgo(from: Date, to: Date) -> String {
        let ms = max(0, to.timeIntervalSince(from) * 1000)
        if ms < 45_000 { return "just now" }
        let mins = Int((ms / 60_000).rounded())
        if mins < 60 { return "\(mins)m ago" }
        let hrs = Int((Double(mins) / 60).rounded())
        if hrs < 36 { return "\(hrs)h ago" }
        let days = Int((Double(hrs) / 24).rounded())
        return "\(days)d ago"
    }

    // MARK: - Tokens

    private var primaryText: Color {
        colorScheme == .dark
            ? Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255)
            : Color(red: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255)
    }

    private var secondaryText: Color {
        colorScheme == .dark
            ? Color(red: 0xa1 / 255, green: 0xa1 / 255, blue: 0xa6 / 255)
            : Color(red: 0x6e / 255, green: 0x6e / 255, blue: 0x73 / 255)
    }

    private var divider: Color {
        colorScheme == .dark
            ? Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3c / 255)
            : Color(red: 0xd2 / 255, green: 0xd2 / 255, blue: 0xd7 / 255)
    }

    private var panelBackground: some View {
        Color.clear
            .background(.ultraThinMaterial)
    }
}

/// Proto action row: hover/press → `--menu-hover` fill + white label (incl. shortcut).
/// Hover state lives on the row (not inside `ButtonStyle`) so MenuBarExtra windows get
/// `onContinuousHover` the same way the chart overlay does.
struct PanelActionRow: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.menuRowMetrics) private var metrics

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .opacity(0.55)
                        .padding(.leading, 16)
                }
            }
            .font(.system(size: metrics.fontSize))
            .padding(.horizontal, metrics.inset)
            .padding(.vertical, 2)
            .frame(minHeight: metrics.rowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(PanelActionButtonStyle(isHovered: isEnabled && isHovered))
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
    }
}

/// Header version chip: same white-on-blue hover/press as action rows; opens changelog.
private struct VersionChangelogButton: View {
    var idleForeground: Color

    @State private var isHovered = false

    var body: some View {
        Button {
            #if !PANEL_PREVIEW
                AboutWindowHost.shared.showChangelog()
            #endif
        } label: {
            Text("v\(QuotAIAboutInfo.versionLabel)")
                .monospacedDigit()
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(
            PanelActionButtonStyle(
                isHovered: isHovered,
                idleForeground: idleForeground.opacity(0.72)
            )
        )
        .help("Release notes")
        .accessibilityLabel("Version \(QuotAIAboutInfo.versionLabel)")
        .accessibilityHint("Opens release notes")
        .onContinuousHover { phase in
            switch phase {
            case .active:
                isHovered = true
            case .ended:
                isHovered = false
            }
        }
    }
}

private struct PanelActionButtonStyle: ButtonStyle {
    var isHovered: Bool
    var idleForeground: Color? = nil
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    private var normalText: Color {
        colorScheme == .dark
            ? Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255)
            : Color(red: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255)
    }

    /// Menu blue highlight (`--menu-hover` in the proto) with a white label.
    private var highlightFill: Color {
        Color(red: 0x0a / 255, green: 0x82 / 255, blue: 1)
    }

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isEnabled && (configuration.isPressed || isHovered)
        return configuration.label
            .foregroundStyle(highlighted ? Color.white : (idleForeground ?? normalText))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(highlighted ? highlightFill : Color.clear)
            )
    }
}
