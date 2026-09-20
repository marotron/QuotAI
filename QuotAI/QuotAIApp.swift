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
        MenuBarExtra {
            if store.isRefreshing {
                Text("Refreshing…")
            } else if let when = store.lastRefreshed {
                Text("Updated \(when.formatted(date: .omitted, time: .shortened))")
            } else {
                Text("QuotAI")
            }
            Divider()
            ForEach(presentation.rows, id: \.self) { row in
                Text(row)
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
            Picker("Icon color", selection: $iconColorMode) {
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
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            if mode == .usedAndDays, store.authError == nil {
                // Monochrome → template so macOS colors it like the other status items.
                Image(nsImage: compactIcon)
                    .renderingMode(iconColorMode == .monochrome ? .template : .original)
            } else {
                HStack(spacing: 4) {
                    Image(nsImage: symbolIcon)
                    Text(presentation.barTitle)
                }
            }
        }
    }

    /// Cursor (+ optional Other Models stacked) and Grok: avatar · bar(s) · percent · time.
    private var compactIcon: NSImage {
        let cursor = store.cursorModels
        let other = store.otherModels
        let grok = store.grokBot

        let cursorFills: [Double?]
        let cursorColors: [NSColor?]
        if showOtherModels {
            let a = cursor.isUnavailable ? nil : cursor.percentUsed
            let b = other.isUnavailable ? nil : other.percentUsed
            cursorFills = [a, b]
            cursorColors = [
                paceBarColor(cursor),
                paceBarColor(other),
            ]
        } else {
            let a = cursor.isUnavailable ? nil : cursor.percentUsed
            cursorFills = [a]
            cursorColors = [paceBarColor(cursor)]
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
        let rows = [
            BarIcon.Row(
                avatar: .cursor,
                fills: cursorFills,
                remaining: cursorRemaining,
                barColors: cursorColors,
                timeline: showRemaining ? cursorTimeline : nil
            ),
            BarIcon.Row(
                avatar: .grok,
                fills: [grokFill],
                remaining: grok.isUnavailable ? nil : grok.secondsRemaining.map(RemainingTime.format(seconds:)),
                barColors: [paceBarColor(grok)],
                timeline: showRemaining ? grokTimeline : nil
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

    private func tintColor(_ tint: SymbolTint) -> NSColor {
        switch tint {
        case .neutral: return .labelColor
        case .under: return .systemBlue
        case .ok: return .systemGreen
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    /// Bars follow pace: blue under / green on / red over (nil when monochrome or unknown).
    private func paceBarColor(_ meter: QuotaMeter) -> NSColor? {
        guard iconColorMode == .byLevel, !meter.isUnavailable else { return nil }
        let tint = MenuPresenter.tint(pace: meter.pace)
        guard tint != .neutral else { return nil }
        return tintColor(tint)
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
