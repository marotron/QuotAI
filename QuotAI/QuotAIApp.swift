import AppKit
import SwiftUI
import QuotAICore

@main
struct QuotAIApp: App {
    @StateObject private var store = QuotaStore()
    @State private var mode: BarDisplayMode = .usedAndDays
    @AppStorage("iconColorMode") private var iconColorMode: IconColorMode = .monochrome
    @AppStorage("showRemaining") private var showRemaining = false
    @AppStorage("showPercent") private var showPercent = true
    @AppStorage("showAvatars") private var showAvatars = true
    @AppStorage("showOtherModels") private var showOtherModels = false
    @AppStorage("blinkSignificantPace") private var blinkSignificantPace = false
    /// Pace ratio % below which blink fires when enabled (default 75%).
    @AppStorage("blinkUnderPercent") private var blinkUnderPercent = 75
    /// Pace ratio % above which blink fires when enabled (default 130%).
    @AppStorage("blinkOverPercent") private var blinkOverPercent = 130

    private static let blinkUnderChoices = [50, 60, 70, 75, 80, 85]
    private static let blinkOverChoices = [115, 120, 125, 130, 140, 150]

    private var presentation: MenuPresentation {
        MenuPresenter.present(
            cursorModels: store.cursorModels,
            otherModels: showOtherModels ? store.otherModels : nil,
            grokBot: store.grokBot,
            mode: mode,
            authError: store.authError
        )
    }

    var body: some Scene {
        // `.menu` → native NSMenu (Wi‑Fi / VPN style). Avoid `.window` chrome for buttons/pickers.
        MenuBarExtra {
            if store.isRefreshing {
                Text("Refreshing…")
            } else if let when = store.lastRefreshed {
                Text("Updated \(when.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("QuotAI")
            }
            Divider()
            ForEach(presentation.notices, id: \.self) { notice in
                Text(notice)
            }
            ForEach(presentation.meters) { meter in
                Text(MeterInfoRow.title(for: meter))
                if let note = meter.note {
                    // Separate item — NSMenu strips newlines inside a single title.
                    Text(note)
                }
            }
            Divider()
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .onAppear {
                Task { await store.refreshIfStale() }
            }
            Button("Re-auth from Cursor") {
                Task { await store.reauthFromCursor() }
            }
            Button("Paste token…") {
                promptPasteToken()
            }
            Button("Open Cursor Spending") {
                NSWorkspace.shared.open(MenuPresenter.spendingURL)
            }
            Divider()
            Picker("Bar mode", selection: $mode) {
                Text("Used + days").tag(BarDisplayMode.usedAndDays)
                Text("Pace").tag(BarDisplayMode.pace)
            }
            Picker("Color mode", selection: $iconColorMode) {
                Text("Monochrome").tag(IconColorMode.monochrome)
                Text("By pace").tag(IconColorMode.byLevel)
            }
            Picker("Refresh every", selection: $store.pollIntervalMinutes) {
                ForEach(QuotaStore.pollIntervalChoices, id: \.self) { minutes in
                    Text(minutes == 60 ? "1 hour" : "\(minutes) min").tag(minutes)
                }
            }
            Toggle("Show Other Models", isOn: $showOtherModels)
            Toggle("Show icons", isOn: $showAvatars)
            Toggle("Show percentage", isOn: $showPercent)
            Toggle("Show time to reset", isOn: $showRemaining)
            Toggle("Blink on significant pace", isOn: $blinkSignificantPace)
            if blinkSignificantPace {
                Picker("Blink under", selection: $blinkUnderPercent) {
                    ForEach(Self.blinkUnderChoices, id: \.self) { pct in
                        Text("Below \(pct)% pace").tag(pct)
                    }
                }
                Picker("Blink over", selection: $blinkOverPercent) {
                    ForEach(Self.blinkOverChoices, id: \.self) { pct in
                        Text("Above \(pct)% pace").tag(pct)
                    }
                }
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            // Own view + state so icon animation ticks do not rebuild the menu (which dismisses Pickers).
            MenuBarIconLabel(
                store: store,
                mode: mode,
                iconColorMode: iconColorMode,
                showRemaining: showRemaining,
                showPercent: showPercent,
                showAvatars: showAvatars,
                showOtherModels: showOtherModels,
                blinkSignificantPace: blinkSignificantPace,
                blinkUnderPercent: blinkUnderPercent,
                blinkOverPercent: blinkOverPercent
            )
        }
        .menuBarExtraStyle(.menu)
    }

    private func promptPasteToken() {
        let alert = NSAlert()
        alert.messageText = "Paste Cursor access token"
        alert.informativeText = "Optional refresh token on the second line. Tokens stay in Keychain only."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 64))
        field.placeholderString = "accessToken\nrefreshToken"
        alert.accessoryView = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let lines = field.stringValue
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let access = lines.first else { return }
        store.pasteAccessToken(access, refreshToken: lines.count > 1 ? lines[1] : nil)
    }
}

/// Builds the main meter title for a native menu row (emoji + copy).
/// Notes are rendered as a following menu item so NSMenu does not drop them.
private enum MeterInfoRow {
    static func title(for meter: MenuMeterRow) -> String {
        "\(bandMark(for: meter.band))\(meter.title)"
    }

    /// Colored emoji survives NSMenu vibrancy; SF Symbol Labels often do not.
    static func bandMark(for band: PaceBand) -> String {
        switch band {
        case .under: return "❄️ "
        case .on: return "✅ "
        case .over, .exhausted: return "🔥 "
        case .unavailable, .neutral: return ""
        }
    }
}

/// Status-item label. Animation state lives here so timer ticks do not invalidate MenuBarExtra content.
private struct MenuBarIconLabel: View {
    @ObservedObject var store: QuotaStore
    let mode: BarDisplayMode
    let iconColorMode: IconColorMode
    let showRemaining: Bool
    let showPercent: Bool
    let showAvatars: Bool
    let showOtherModels: Bool
    let blinkSignificantPace: Bool
    let blinkUnderPercent: Int
    let blinkOverPercent: Int

    @State private var iconAnimDate = Date()
    private let iconAnimTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var blinkUnderRatio: Double { Double(blinkUnderPercent) / 100 }
    private var blinkOverRatio: Double { Double(blinkOverPercent) / 100 }

    private var presentation: MenuPresentation {
        MenuPresenter.present(
            cursorModels: store.cursorModels,
            otherModels: showOtherModels ? store.otherModels : nil,
            grokBot: store.grokBot,
            mode: mode,
            authError: store.authError
        )
    }

    var body: some View {
        Group {
            if mode == .usedAndDays, store.authError == nil {
                Image(nsImage: compactIcon(at: iconAnimDate))
                    .renderingMode(iconColorMode == .monochrome ? .template : .original)
            } else {
                HStack(spacing: 4) {
                    Image(nsImage: symbolIcon)
                    Text(presentation.barTitle)
                }
            }
        }
        .onReceive(iconAnimTimer) { date in
            guard needsAnimatedIcon else { return }
            iconAnimDate = date
        }
    }

    private var needsAnimatedIcon: Bool {
        needsCursorAvatarPulse || needsSignificantBlink
    }

    /// Cursor Models + Other Models both have a pace tint and they disagree → animate the cube.
    private var needsCursorAvatarPulse: Bool {
        guard iconColorMode == .byLevel, showAvatars, showOtherModels else { return false }
        guard let a = paceTint(store.cursorModels), let b = paceTint(store.otherModels) else { return false }
        return a != b
    }

    private var needsSignificantBlink: Bool {
        guard blinkSignificantPace else { return false }
        if meterNeedsBlink(store.cursorModels) { return true }
        if showOtherModels, meterNeedsBlink(store.otherModels) { return true }
        return meterNeedsBlink(store.grokBot)
    }

    /// Cursor (+ optional Other Models stacked) and Grok: avatar · bar(s) · percent · time.
    private func compactIcon(at date: Date) -> NSImage {
        let cursor = store.cursorModels
        let other = store.otherModels
        let grok = store.grokBot

        let cursorFills: [Double?]
        let cursorBaseColors: [NSColor?]
        let cursorMeters: [QuotaMeter]
        if showOtherModels {
            let a = cursor.isUnavailable ? nil : cursor.percentUsed
            let b = other.isUnavailable ? nil : other.percentUsed
            cursorFills = [a, b]
            cursorBaseColors = [paceBarColor(cursor), paceBarColor(other)]
            cursorMeters = [cursor, other]
        } else {
            let a = cursor.isUnavailable ? nil : cursor.percentUsed
            cursorFills = [a]
            cursorBaseColors = [paceBarColor(cursor)]
            cursorMeters = [cursor]
        }
        let cursorColors = zip(cursorBaseColors, cursorMeters).map { color, meter in
            blinkedBarColor(color, meter: meter, at: date)
        }

        // Same billing cycle for Cursor Models + Other Models → one shared remaining + timeline.
        let cursorRemaining: String? = {
            if cursor.isUnavailable, !showOtherModels || other.isUnavailable { return nil }
            let seconds = cursor.secondsRemaining ?? other.secondsRemaining
            return seconds.map(RemainingTime.format(seconds:))
        }()
        let cursorTimeline = cursor.periodElapsedPercent() ?? other.periodElapsedPercent()
        let grokTimeline = grok.periodElapsedPercent()

        let grokFill = grok.isUnavailable ? nil : grok.percentUsed
        let grokBaseColors: [NSColor?] = [paceBarColor(grok)]
        let grokColors = [blinkedBarColor(grokBaseColors[0], meter: grok, at: date)]
        let rows = [
            BarIcon.Row(
                avatar: .cursor,
                fills: cursorFills,
                remaining: cursorRemaining,
                barColors: cursorColors,
                avatarColor: blinkedAvatarColor(
                    lightAvatarColor(from: cursorBaseColors, at: date),
                    meters: cursorMeters,
                    at: date
                ),
                timeline: cursorTimeline
            ),
            BarIcon.Row(
                avatar: .grok,
                fills: [grokFill],
                remaining: grok.isUnavailable ? nil : grok.secondsRemaining.map(RemainingTime.format(seconds:)),
                barColors: grokColors,
                avatarColor: blinkedAvatarColor(
                    lightAvatarColor(from: grokBaseColors, at: date),
                    meters: [grok],
                    at: date
                ),
                timeline: grokTimeline
            ),
        ]
        return BarIcon.image(
            rows: rows,
            showAvatars: showAvatars,
            showPercent: showPercent,
            showRemaining: showRemaining,
            foreground: .white
        )
    }

    /// Template (monochrome) or palette-tinted symbol; NSImage so the status item honors the color.
    private var symbolIcon: NSImage {
        let base = NSImage(systemSymbolName: presentation.symbolName, accessibilityDescription: nil)
            ?? NSImage()
        switch iconColorMode {
        case .monochrome:
            base.isTemplate = true
            return base
        case .byLevel:
            let config = NSImage.SymbolConfiguration(paletteColors: [tintColor(presentation.tint)])
            let tinted = base.withSymbolConfiguration(config) ?? base
            tinted.isTemplate = false
            return tinted
        }
    }

    /// Menu-bar fills: brighter than system colors, richer than pastel wash.
    private func tintColor(_ tint: SymbolTint) -> NSColor {
        switch tint {
        case .neutral: return .labelColor
        case .under: return NSColor(calibratedRed: 0.35, green: 0.68, blue: 1.0, alpha: 1)
        case .ok: return NSColor(calibratedRed: 0.28, green: 0.82, blue: 0.45, alpha: 1)
        case .warning: return NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.22, alpha: 1)
        case .critical: return NSColor(calibratedRed: 1.0, green: 0.25, blue: 0.30, alpha: 1)
        }
    }

    private func paceTint(_ meter: QuotaMeter) -> SymbolTint? {
        guard iconColorMode == .byLevel, !meter.isUnavailable else { return nil }
        let tint = MenuPresenter.tint(pace: meter.pace)
        return tint == .neutral ? nil : tint
    }

    /// Bars follow pace: blue under / green on / red over (nil when monochrome or unknown).
    private func paceBarColor(_ meter: QuotaMeter) -> NSColor? {
        guard let tint = paceTint(meter) else { return nil }
        return tintColor(tint)
    }

    private func meterNeedsBlink(_ meter: QuotaMeter) -> Bool {
        guard blinkSignificantPace, !meter.isUnavailable else { return false }
        return PaceCalculator.isSignificant(
            pace: meter.pace,
            under: blinkUnderRatio,
            over: blinkOverRatio
        )
    }

    /// ~1s hard on/off for significant under/over fills (matches 0.5s TimelineView tick).
    private func blinkLit(at date: Date) -> Bool {
        Int(date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0
    }

    private func blinkedBarColor(_ base: NSColor?, meter: QuotaMeter, at date: Date) -> NSColor? {
        guard meterNeedsBlink(meter) else { return base }
        if blinkLit(at: date) { return base }
        if let base { return base.withAlphaComponent(0.35) }
        // Monochrome: dim the ink fill while "off".
        return NSColor.white.withAlphaComponent(0.35)
    }

    private func blinkedAvatarColor(_ base: NSColor?, meters: [QuotaMeter], at date: Date) -> NSColor? {
        guard meters.contains(where: meterNeedsBlink) else { return base }
        if blinkLit(at: date) { return base }
        if let base { return base.withAlphaComponent(0.4) }
        return NSColor.white.withAlphaComponent(0.4)
    }

    /// Avatar tint: light mix toward white. Dual distinct colors → alternate on the same 0.5s tick.
    private func lightAvatarColor(from barColors: [NSColor?], at date: Date) -> NSColor? {
        let colors = barColors.compactMap { $0 }
        guard let first = colors.first else { return nil }
        let blended: NSColor
        if colors.count >= 2, !colors[0].isEqual(colors[1]) {
            blended = blinkLit(at: date) ? colors[0] : colors[1]
        } else {
            blended = first
        }
        return lighten(blended, towardWhite: 0.22)
    }

    private func lighten(_ color: NSColor, towardWhite amount: CGFloat) -> NSColor {
        let c = color.usingColorSpace(.deviceRGB) ?? color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let m = min(max(amount, 0), 1)
        return NSColor(
            calibratedRed: r + (1 - r) * m,
            green: g + (1 - g) * m,
            blue: b + (1 - b) * m,
            alpha: 1
        )
    }
}
