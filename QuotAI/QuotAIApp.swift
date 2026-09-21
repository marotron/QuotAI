import AppKit
import SwiftUI
import QuotAICore

@main
struct QuotAIApp: App {
    @StateObject private var store = QuotaStore()
    @AppStorage("iconColorMode") private var iconColorMode: IconColorMode = .monochrome
    @AppStorage("showRemaining") private var showRemaining = false
    @AppStorage("showPercent") private var showPercent = true
    @AppStorage("showAvatars") private var showAvatars = true
    @AppStorage("showOtherModels") private var showOtherModels = false
    @AppStorage("blinkSignificantPace") private var blinkSignificantPace = false
    @AppStorage("blinkUnderPercent") private var blinkUnderPercent = 75
    @AppStorage("blinkOverPercent") private var blinkOverPercent = 130
    @AppStorage("paceOnLoPercent") private var paceOnLoPercent = 90
    @AppStorage("paceOnHiPercent") private var paceOnHiPercent = 110
    @AppStorage("useSmartPaceAlerts") private var useSmartPaceAlerts = true
    @AppStorage("overMaxStartPct") private var overMaxStartPct = 25
    @AppStorage("overEmptyBeforePct") private var overEmptyBeforePct = 95
    @AppStorage("underAfterPct") private var underAfterPct = 25
    @AppStorage("underMinEndPct") private var underMinEndPct = 95
    @AppStorage("overCurvePct") private var overCurvePct = 0
    @AppStorage("underCurvePct") private var underCurvePct = 0

    @AppStorage("pinRefreshInterval") private var pinRefreshInterval = true
    @AppStorage("pinColorMode") private var pinColorMode = false
    @AppStorage("pinOnPaceBand") private var pinOnPaceBand = false
    @AppStorage("pinShowOtherModels") private var pinShowOtherModels = false
    @AppStorage("pinShowAvatars") private var pinShowAvatars = false
    @AppStorage("pinShowPercent") private var pinShowPercent = false
    @AppStorage("pinShowRemaining") private var pinShowRemaining = false
    @AppStorage("pinBlink") private var pinBlink = false

    private static let deadZonePresets: [(lo: Int, hi: Int)] = [
        (95, 105),
        (90, 110),
        (85, 115),
        (80, 120),
    ]

    private var onPaceLo: Double { Double(min(paceOnLoPercent, paceOnHiPercent)) / 100 }
    private var onPaceHi: Double { Double(max(paceOnLoPercent, paceOnHiPercent)) / 100 }

    private var smartThresholds: PaceAlertThresholds {
        PaceAlertThresholds(
            overMaxStartPct: Double(overMaxStartPct),
            overEmptyBeforePct: Double(overEmptyBeforePct),
            underAfterPct: Double(underAfterPct),
            underMinEndPct: Double(underMinEndPct),
            overCurvePct: Double(overCurvePct),
            underCurvePct: Double(underCurvePct)
        )
    }

    private var presentation: MenuPresentation {
        let presented = MenuPresenter.present(
            cursorModels: store.cursorModels,
            otherModels: showOtherModels ? store.otherModels : nil,
            grokBot: store.grokBot,
            authError: store.authError,
            onPaceLo: onPaceLo,
            onPaceHi: onPaceHi
        )
        MeterMenuBadges.shared.meters = presented.meters
        return presented
    }

    init() {
        MeterMenuBadges.shared.install()
        NotificationAlertService.install()
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
                // Button (not Text) → enabled NSMenuItem so marks/title are not dimmed.
                // Colors still painted via MeterMenuBadges on open.
                Button(MeterMenuBadges.titleWithFallbackMark(for: meter)) {}
                if let note = MeterMenuBadges.noteWithIndent(for: meter) {
                    // Separate item — NSMenu strips newlines inside a single title.
                    // Same leading mark width as the title row so copy lines up.
                    Button(note) {}
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
            if hasPinnedPrefs {
                Divider()
                if pinColorMode {
                    Picker("Color mode", selection: $iconColorMode) {
                        Text("Monochrome").tag(IconColorMode.monochrome)
                        Text("By pace").tag(IconColorMode.byLevel)
                    }
                }
                if pinOnPaceBand {
                    Picker("On-pace band", selection: deadZoneSelection) {
                        ForEach(Self.deadZonePresets, id: \.lo) { preset in
                            Text("\(preset.lo)–\(preset.hi)%").tag(deadZoneTag(lo: preset.lo, hi: preset.hi))
                        }
                    }
                }
                if pinRefreshInterval {
                    Picker("Refresh every", selection: $store.pollIntervalMinutes) {
                        ForEach(QuotaStore.pollIntervalChoices, id: \.self) { minutes in
                            Text(minutes == 60 ? "1 hour" : "\(minutes) min").tag(minutes)
                        }
                    }
                }
                if pinShowOtherModels {
                    Toggle("Show Other Models", isOn: $showOtherModels)
                }
                if pinShowAvatars {
                    Toggle("Show icons", isOn: $showAvatars)
                }
                if pinShowPercent {
                    Toggle("Show percentage", isOn: $showPercent)
                }
                if pinShowRemaining {
                    Toggle("Show time to reset", isOn: $showRemaining)
                }
                if pinBlink {
                    Toggle("Blink on significant pace", isOn: $blinkSignificantPace)
                }
            }
            Divider()
            MenuSettingsButton()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            // Own view + state so icon animation ticks do not rebuild the menu (which dismisses Pickers).
            MenuBarIconLabel(
                store: store,
                iconColorMode: iconColorMode,
                showRemaining: showRemaining,
                showPercent: showPercent,
                showAvatars: showAvatars,
                showOtherModels: showOtherModels,
                blinkSignificantPace: blinkSignificantPace,
                blinkUnderPercent: blinkUnderPercent,
                blinkOverPercent: blinkOverPercent,
                useSmartPaceAlerts: useSmartPaceAlerts,
                smartThresholds: smartThresholds,
                onPaceLo: onPaceLo,
                onPaceHi: onPaceHi
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(store: store)
        }
    }

    private var hasPinnedPrefs: Bool {
        pinRefreshInterval || pinColorMode || pinOnPaceBand || pinShowOtherModels
            || pinShowAvatars || pinShowPercent || pinShowRemaining || pinBlink
    }

    private func deadZoneTag(lo: Int, hi: Int) -> String { "\(lo)-\(hi)" }

    /// Bridges two AppStorage ints to one Picker selection.
    private var deadZoneSelection: Binding<String> {
        Binding(
            get: { deadZoneTag(lo: paceOnLoPercent, hi: paceOnHiPercent) },
            set: { tag in
                let parts = tag.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 2 else { return }
                paceOnLoPercent = parts[0]
                paceOnHiPercent = parts[1]
            }
        )
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

/// Pace marks live in the title as unicode (❄ ✓ ♨). Colors are applied through
/// `NSMenuItem.attributedTitle` on menu open — SwiftUI foreground styles are washed out by NSMenu.
///
/// SwiftUI paints plain titles first (visible marks on note rows). We rewrite as soon as the
/// menu begins tracking, again on the next run-loop turns / item inserts, and whenever `meters`
/// updates while open — otherwise the first open can stick on the unstyled fallback (img1).
private final class MeterMenuBadges: NSObject {
    static let shared = MeterMenuBadges()

    /// Text presentation (VS15) so `foregroundColor` can tint the glyph.
    private static let textStyle = "\u{FE0E}"

    var meters: [MenuMeterRow] = [] {
        didSet { reapplyTrackingMenu() }
    }

    private var installed = false
    private weak var trackingMenu: NSMenu?
    private var pendingApply: DispatchWorkItem?

    func install() {
        guard !installed else { return }
        installed = true
        let nc = NotificationCenter.default
        nc.addObserver(
            self,
            selector: #selector(menuDidBeginTracking(_:)),
            name: NSMenu.didBeginTrackingNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(menuDidEndTracking(_:)),
            name: NSMenu.didEndTrackingNotification,
            object: nil
        )
        nc.addObserver(
            self,
            selector: #selector(menuDidAddItem(_:)),
            name: NSMenu.didAddItemNotification,
            object: nil
        )
    }

    /// Mark + title. Survives NSMenu; color is painted in `apply(to:)`.
    static func titleWithFallbackMark(for meter: MenuMeterRow) -> String {
        "\(fallbackMark(for: meter)) \(meter.title)"
    }

    /// Note prefixed with the same mark column as the title (invisible in AppKit apply).
    static func noteWithIndent(for meter: MenuMeterRow) -> String? {
        guard let note = meter.note else { return nil }
        return "\(fallbackMark(for: meter)) \(note)"
    }

    private static func fallbackMark(for meter: MenuMeterRow) -> String {
        switch meter.band {
        case .under: return "❄\(textStyle)"
        case .on: return "✓\(textStyle)"
        case .over, .exhausted: return "♨\(textStyle)"
        case .unavailable, .neutral: return "○"
        }
    }

    @objc private func menuDidBeginTracking(_ note: Notification) {
        guard let menu = note.object as? NSMenu else { return }
        // Tentatively track the first open menu so meters didSet can re-apply before
        // SwiftUI has inserted recognizable meter rows.
        if trackingMenu == nil {
            trackingMenu = menu
        }
        adoptIfMeterMenu(menu)
        apply(to: menu)
        // Items / meters often arrive after tracking starts (SwiftUI build, refreshIfStale).
        scheduleApply(menu)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.adoptIfMeterMenu(menu)
            self.apply(to: self.trackingMenu ?? menu)
        }
    }

    @objc private func menuDidEndTracking(_ note: Notification) {
        guard let menu = note.object as? NSMenu, trackingMenu === menu else { return }
        pendingApply?.cancel()
        pendingApply = nil
        trackingMenu = nil
    }

    @objc private func menuDidAddItem(_ note: Notification) {
        guard let menu = note.object as? NSMenu else { return }
        // SwiftUI may insert meter rows after tracking begins (meters still empty on first open).
        guard trackingMenu === menu || containsMeterItems(menu) else { return }
        adoptIfMeterMenu(menu)
        scheduleApply(menu)
    }

    private func reapplyTrackingMenu() {
        guard let menu = trackingMenu else { return }
        scheduleApply(menu)
    }

    private func adoptIfMeterMenu(_ menu: NSMenu) {
        if containsMeterItems(menu) {
            trackingMenu = menu
        }
    }

    /// Coalesce rapid didAddItem / meters updates onto the next turn.
    private func scheduleApply(_ menu: NSMenu) {
        pendingApply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let target = self.trackingMenu ?? menu
            self.adoptIfMeterMenu(target)
            self.apply(to: target)
        }
        pendingApply = work
        DispatchQueue.main.async(execute: work)
    }

    private func containsMeterItems(_ menu: NSMenu) -> Bool {
        let meters = meters
        guard !meters.isEmpty else { return false }
        return menu.items.contains {
            meter(forTitle: $0.title, meters: meters) != nil
                || meter(forNoteTitle: $0.title, meters: meters) != nil
        }
    }

    private func apply(to menu: NSMenu) {
        let meters = meters
        guard !meters.isEmpty else { return }
        guard containsMeterItems(menu) else { return }

        let menuFont = NSFont.menuFont(ofSize: 0)
        let noteFont = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)
        for item in menu.items {
            if let meter = meter(forTitle: item.title, meters: meters) {
                item.isEnabled = true
                item.image = nil
                item.attributedTitle = Self.coloredTitle(for: meter, font: menuFont)
            } else if let meter = meter(forNoteTitle: item.title, meters: meters),
                      let note = meter.note {
                item.isEnabled = true
                item.image = nil
                item.attributedTitle = Self.indentedNote(note, matching: meter, font: noteFont)
            }
        }
    }

    private func meter(forTitle title: String, meters: [MenuMeterRow]) -> MenuMeterRow? {
        if let exact = meters.first(where: { $0.title == title }) { return exact }
        // "❄︎ <title>" from SwiftUI before attributedTitle rewrite.
        return meters.first { meter in
            guard title.hasSuffix(meter.title), title != meter.title else { return false }
            // Note rows also end with text after a mark — exclude those.
            if let note = meter.note, title.hasSuffix(note) { return false }
            return true
        }
    }

    private func meter(forNoteTitle title: String, meters: [MenuMeterRow]) -> MenuMeterRow? {
        meters.first { meter in
            guard let note = meter.note else { return false }
            return title == note || title.hasSuffix(note)
        }
    }

    private static func coloredTitle(for meter: MenuMeterRow, font: NSFont) -> NSAttributedString {
        let mark = fallbackMark(for: meter)
        let markFont = NSFont.menuFont(ofSize: font.pointSize + 1)
        let ns = NSMutableAttributedString(
            string: "\(mark) ",
            attributes: [
                .font: markFont,
                .foregroundColor: markColor(band: meter.band, shade: meter.shade),
            ]
        )
        ns.append(NSAttributedString(
            string: meter.title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]
        ))
        return ns
    }

    /// Same mark column as the title row, drawn clear so note text lines up under the title.
    private static func indentedNote(_ note: String, matching meter: MenuMeterRow, font: NSFont) -> NSAttributedString {
        let mark = fallbackMark(for: meter)
        let markFont = NSFont.menuFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize + 1)
        let ns = NSMutableAttributedString(
            string: "\(mark) ",
            attributes: [
                .font: markFont,
                .foregroundColor: NSColor.clear,
            ]
        )
        ns.append(NSAttributedString(
            string: note,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        return ns
    }

    /// Saturated marks — must read clearly on light menu chrome.
    private static func markColor(band: PaceBand, shade: PaceShade) -> NSColor {
        switch band {
        case .under:
            return NSColor(calibratedRed: 0.00, green: 0.42, blue: 0.98, alpha: 1)
        case .on:
            return NSColor(calibratedRed: 0.00, green: 0.62, blue: 0.28, alpha: 1)
        case .over:
            return overColor(shade: shade)
        case .exhausted:
            return NSColor(calibratedRed: 0.92, green: 0.08, blue: 0.18, alpha: 1)
        case .unavailable, .neutral:
            return NSColor.secondaryLabelColor
        }
    }

    private static func overColor(shade: PaceShade) -> NSColor {
        switch shade {
        case .none, .mild:
            return NSColor(calibratedRed: 0.95, green: 0.48, blue: 0.00, alpha: 1)
        case .medium:
            return NSColor(calibratedRed: 0.95, green: 0.32, blue: 0.05, alpha: 1)
        case .strong:
            return NSColor(calibratedRed: 0.92, green: 0.08, blue: 0.18, alpha: 1)
        }
    }
}

/// Status-item label. Animation state lives here so timer ticks do not invalidate MenuBarExtra content.
private struct MenuBarIconLabel: View {
    @ObservedObject var store: QuotaStore
    let iconColorMode: IconColorMode
    let showRemaining: Bool
    let showPercent: Bool
    let showAvatars: Bool
    let showOtherModels: Bool
    let blinkSignificantPace: Bool
    let blinkUnderPercent: Int
    let blinkOverPercent: Int
    let useSmartPaceAlerts: Bool
    let smartThresholds: PaceAlertThresholds
    let onPaceLo: Double
    let onPaceHi: Double

    @State private var iconAnimDate = Date()
    /// Half-cycle for blink / dual-avatar pulse (~2s full period).
    private let iconAnimTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var blinkUnderRatio: Double { Double(blinkUnderPercent) / 100 }
    private var blinkOverRatio: Double { Double(blinkOverPercent) / 100 }

    private var presentation: MenuPresentation {
        MenuPresenter.present(
            cursorModels: store.cursorModels,
            otherModels: showOtherModels ? store.otherModels : nil,
            grokBot: store.grokBot,
            authError: store.authError,
            onPaceLo: onPaceLo,
            onPaceHi: onPaceHi
        )
    }

    var body: some View {
        Group {
            if store.authError == nil {
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
        let tint = MenuPresenter.tint(pace: meter.pace, onPaceLo: onPaceLo, onPaceHi: onPaceHi)
        return tint == .neutral ? nil : tint
    }

    /// Bars follow pace: blue under / green on / red over (nil when monochrome or unknown).
    private func paceBarColor(_ meter: QuotaMeter) -> NSColor? {
        guard let tint = paceTint(meter) else { return nil }
        return tintColor(tint)
    }

    private func meterNeedsBlink(_ meter: QuotaMeter) -> Bool {
        guard blinkSignificantPace, !meter.isUnavailable else { return false }
        if let pct = meter.percentUsed,
           let start = meter.periodStart,
           let end = meter.periodEnd,
           let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end) {
            let kind = PaceAlertBands.evaluate(
                percentUsed: pct,
                elapsedFraction: t,
                thresholds: smartThresholds,
                smart: useSmartPaceAlerts,
                legacyUnder: blinkUnderRatio,
                legacyOver: blinkOverRatio
            )
            return PaceAlertBands.isSignificant(kind: kind)
        }
        // Exhausted / missing dates → fall back to pace result.
        return PaceCalculator.isSignificant(
            pace: meter.pace,
            under: blinkUnderRatio,
            over: blinkOverRatio
        )
    }

    /// ~2s hard on/off for significant under/over fills (1s half-cycle).
    private func blinkLit(at date: Date) -> Bool {
        Int(date.timeIntervalSinceReferenceDate / 1.0) % 2 == 0
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

    /// Avatar tint: light mix toward white. Dual distinct colors → alternate on the same 1s tick.
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
