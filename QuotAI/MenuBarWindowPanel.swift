import AppKit
import SwiftUI
import QuotAICore

/// MenuBarExtra `.window` content: status, meters, pace history chart, actions.
struct MenuBarWindowPanel: View {
    @ObservedObject var store: QuotaStore
    var showOtherModels: Bool
    var corridorAlertsEnabled: Bool
    var smartThresholds: PaceAlertThresholds

    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme

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

            actionRow("Refresh all") {
                Task { await store.refresh(.all) }
            }
            .padding(.horizontal, 5)
            .disabled(store.isRefreshing)

            panelSeparator

            actionRow("Settings…", shortcut: "⌘,") {
                SettingsWindowElevator.show { openSettings() }
            }
            .keyboardShortcut(",", modifiers: .command)
            .padding(.horizontal, 5)

            actionRow("About") {
                AboutWindowHost.shared.showAbout()
            }
            .padding(.horizontal, 5)

            panelSeparator

            actionRow("Quit QuotAI", shortcut: "⌘Q") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
            .padding(.horizontal, 5)
        }
        .padding(.vertical, 5)
        .frame(width: 470)
        .background(panelBackground)
        .onAppear {
            store.snapDisplayClock()
            Task { await store.refreshIfStale() }
        }
    }

    // MARK: - Status

    private var statusRow: some View {
        HStack(alignment: .firstTextBaseline) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 0) {
                    Text("Last refresh: Cursor ")
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
                    Text(" · Grok Bot ")
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
                series: .models
            )
            if showOtherModels {
                meterRow(
                    title: "Other Models",
                    meter: store.otherModels.projected(at: now),
                    avatar: .cursor,
                    series: .other
                )
            }
            meterRow(
                title: "Grok Bot",
                meter: store.grokBot.projected(at: now),
                avatar: .grok,
                series: .grok
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
        series: PaceHistorySeriesColor
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            seriesAvatar(avatar, series: series)

            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(primaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            if meter.isUnavailable {
                Text("unavailable")
                    .font(.system(size: 11))
                    .foregroundStyle(secondaryText)
            } else {
                // Fixed trailing columns so used / elapsed / pace / reset line up across rows.
                HStack(spacing: 6) {
                    fact(icon: "sparkles", value: usedText(meter))
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                    op("÷")
                    fact(icon: "hourglass.bottomhalf.filled", value: elapsedText(meter))
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                    op("=")
                    paceFact(meter)
                        .frame(width: Self.pctColumnWidth, alignment: .trailing)
                    alertSlot(for: meter)
                    op("→")
                    fact(icon: "timer", value: resetText(meter))
                        .frame(width: Self.resetColumnWidth, alignment: .trailing)
                }
            }
        }
        .frame(minHeight: 20)
    }

    private static let pctColumnWidth: CGFloat = 46
    private static let resetColumnWidth: CGFloat = 98

    private func seriesAvatar(_ avatar: BarIcon.Avatar, series: PaceHistorySeriesColor) -> some View {
        Image(nsImage: BarIcon.tintedAvatar(avatar, ink: Self.nsColor(hex: series.hex), pointSize: 14))
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
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
                thresholds: smartThresholds,
                series: historySeries,
                showOtherModels: showOtherModels
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
    }

    private var historySeries: [PaceHistoryMeterId: [PaceHistorySample]] {
        _ = store.paceHistoryEpoch
        var map: [PaceHistoryMeterId: [PaceHistorySample]] = [:]
        for id in PaceHistoryMeterId.allCases {
            map[id] = store.paceHistoryStore.series(for: id)
        }
        return map
    }

    // MARK: - Actions

    private func actionRow(_ title: String, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
        PanelActionRow(title: title, shortcut: shortcut, action: action)
    }

    private var panelSeparator: some View {
        Rectangle()
            .fill(divider)
            .frame(height: 1)
            .padding(.vertical, 5)
            .padding(.horizontal, 14)
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

    private func alertKind(for meter: QuotaMeter) -> PaceAlertKind {
        guard corridorAlertsEnabled, !meter.isUnavailable else { return .quiet }
        if let pct = meter.percentUsed,
           let start = meter.periodStart,
           let end = meter.periodEnd,
           let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end, now: now) {
            return PaceAlertBands.evaluate(
                percentUsed: pct,
                elapsedFraction: t,
                thresholds: smartThresholds,
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
private struct PanelActionRow: View {
    let title: String
    var shortcut: String? = nil
    let action: () -> Void

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(.system(size: 12))
                        .opacity(0.55)
                        .padding(.leading, 16)
                }
            }
            .font(.system(size: 13))
            .padding(.horizontal, 14)
            .padding(.vertical, 2)
            .frame(minHeight: 22)
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
            AboutWindowHost.shared.showChangelog()
        } label: {
            Text("v\(QuotAIAboutInfo.marketingVersion)")
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
        .accessibilityLabel("Version \(QuotAIAboutInfo.marketingVersion)")
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

    private static let menuHover = Color(red: 0x0a / 255, green: 0x82 / 255, blue: 1)

    private var normalText: Color {
        colorScheme == .dark
            ? Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255)
            : Color(red: 0x1d / 255, green: 0x1d / 255, blue: 0x1f / 255)
    }

    func makeBody(configuration: Configuration) -> some View {
        let highlighted = isEnabled && (configuration.isPressed || isHovered)
        return configuration.label
            .foregroundStyle(highlighted ? Color.white : (idleForeground ?? normalText))
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(highlighted ? Self.menuHover : Color.clear)
            )
    }
}
