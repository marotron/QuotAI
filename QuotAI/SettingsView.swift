import AppKit
import SwiftUI
import QuotAICore

struct SettingsView: View {
    @ObservedObject var store: QuotaStore

    @AppStorage("iconColorMode") private var iconColorMode: IconColorMode = .monochrome
    @AppStorage("iconLook") private var iconLook: IconLook = .bars
    @AppStorage("showRemaining") private var showRemaining = false
    @AppStorage("showPercent") private var showUsedPercent = true
    @AppStorage("showElapsedPercent") private var showElapsedPercent = true
    @AppStorage("alternateElapsedRemaining") private var alternateElapsedRemaining = false
    @AppStorage("showAvatars") private var showAvatars = true
    @AppStorage("ringCenterContent") private var ringCenterContent: RingCenterContent = .remaining
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
    @AppStorage("notifySignificantPace") private var notifySignificantPace = false
    @AppStorage("emailSignificantPace") private var emailSignificantPace = false

    @AppStorage("smtpHost") private var smtpHost = ""
    @AppStorage("smtpPort") private var smtpPort = 465
    @AppStorage("smtpUsername") private var smtpUsername = ""
    @AppStorage("smtpFrom") private var smtpFrom = ""
    @AppStorage("smtpTo") private var smtpTo = ""
    @AppStorage("smtpUseTLS") private var smtpUseTLS = true

    @AppStorage("pinRefreshInterval") private var pinRefreshInterval = true
    @AppStorage("pinColorMode") private var pinColorMode = false
    @AppStorage("pinIconLook") private var pinIconLook = false
    @AppStorage("pinOnPaceBand") private var pinOnPaceBand = false
    @AppStorage("pinShowOtherModels") private var pinShowOtherModels = false
    @AppStorage("pinShowAvatars") private var pinShowAvatars = false
    @AppStorage("pinShowPercent") private var pinShowUsedPercent = false
    @AppStorage("pinShowElapsedPercent") private var pinShowElapsedPercent = false
    @AppStorage("pinShowRemaining") private var pinShowRemaining = false
    @AppStorage("pinAlternateElapsedRemaining") private var pinAlternateElapsedRemaining = false
    @AppStorage("pinRingCenterContent") private var pinRingCenterContent = false
    @AppStorage("pinBlink") private var pinBlink = false
    @AppStorage("pinOpenCursorSpending") private var pinOpenCursorSpending = false

    @State private var smtpPassword = ""
    @State private var emailStatus: String?
    @State private var notifyStatus = ""
    @State private var dialAlertTask: Task<Void, Never>?

    private static let blinkUnderChoices = [50, 60, 70, 75, 80, 85]
    private static let blinkOverChoices = [115, 120, 125, 130, 140, 150]
    private static let deadZonePresets: [(lo: Int, hi: Int)] = [
        (95, 105), (90, 110), (85, 115), (80, 120),
    ]
    /// Shared width for menu pickers so every dropdown control aligns on the right.
    private static let menuControlWidth: CGFloat = 180

    private var thresholds: PaceAlertThresholds {
        PaceAlertThresholds(
            overMaxStartPct: Double(overMaxStartPct),
            overEmptyBeforePct: Double(overEmptyBeforePct),
            underAfterPct: Double(underAfterPct),
            underMinEndPct: Double(underMinEndPct),
            overCurvePct: Double(overCurvePct),
            underCurvePct: Double(underCurvePct)
        )
    }

    private var chartMeters: [(name: String, usedPct: Double, elapsedPct: Double)] {
        var rows: [(String, Double, Double)] = []
        appendChartMeter(name: "Cursor", meter: store.cursorModels, into: &rows)
        if showOtherModels {
            appendChartMeter(name: "Other", meter: store.otherModels, into: &rows)
        }
        appendChartMeter(name: "Grok", meter: store.grokBot, into: &rows)
        return rows
    }

    var body: some View {
        TabView {
            displayTab.tabItem { Label("Display", systemImage: "paintpalette") }
            accountTab.tabItem { Label("Account", systemImage: "person.crop.circle") }
            paceTab.tabItem { Label("Pace", systemImage: "gauge.with.dots.needle.33percent") }
            alertsTab.tabItem { Label("Alerts", systemImage: "bell") }
            emailTab.tabItem { Label("Email", systemImage: "envelope") }
            pinsTab.tabItem { Label("Menu pins", systemImage: "pin") }
        }
        .frame(width: 480, height: 620)
        .onAppear {
            SettingsWindowElevator.raise()
            smtpPassword = EmailAlertService.loadPassword() ?? ""
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private var displayTab: some View {
        settingsForm {
            Section {
                menuPicker("Menu bar style", selection: $iconLook) {
                    Text("Bars").tag(IconLook.bars)
                    Text("Rings · one per meter").tag(IconLook.ringsPerQuota)
                    Text("Rings · nested Cursor").tag(IconLook.ringsPaired)
                    Text("Rings · by pace").tag(IconLook.ringsPace)
                }
                menuPicker("Color mode", selection: $iconColorMode) {
                    Text("Monochrome").tag(IconColorMode.monochrome)
                    Text("By pace").tag(IconColorMode.byLevel)
                }
                Toggle("Show Other Models", isOn: $showOtherModels)
            }

            Section {
                Toggle("Show icons", isOn: $showAvatars)
                Toggle("Show used %", isOn: $showUsedPercent)
                if iconLook == .bars {
                    Toggle("Show time to reset", isOn: $showRemaining)
                } else if iconLook.alternatesElapsedAndRemaining {
                    if !alternateElapsedRemaining {
                        Toggle("Show elapsed %", isOn: $showElapsedPercent)
                        Toggle("Show time to reset", isOn: $showRemaining)
                    }
                    Toggle("Alternate elapsed % / time to reset", isOn: $alternateElapsedRemaining)
                } else {
                    Toggle("Show elapsed %", isOn: $showElapsedPercent)
                    Toggle("Show time to reset", isOn: $showRemaining)
                }
            } header: {
                Text("Beside meter")
            } footer: {
                if iconLook == .bars {
                    Text("Icons, used %, and time sit beside the tracks. When Models is over and Other is under (or the reverse), the Cursor icon slowly alternates those colors.")
                } else if iconLook == .ringsPerQuota, alternateElapsedRemaining {
                    Text("Each meter has its own ring. One label blinks between elapsed % and time to reset (~5s). Used % still stacks above when enabled.")
                } else if iconLook == .ringsPerQuota {
                    Text("Each meter has its own ring. Used % and elapsed % stack beside it. The icon sits beside the ring, or inside when Center is Icon — including Other Models.")
                } else if alternateElapsedRemaining {
                    Text("One label blinks between elapsed % and time to reset (~5s; half the Models ↔ Other pace). Used % still stacks above when enabled.")
                } else {
                    Text("Used and elapsed together stack as two rows, or alone as one larger label. When Models is over and Other is under (or the reverse), the Cursor icon slowly alternates those colors (beside icons, or center when set to Icon).")
                }
            }

            if iconLook != .bars {
                Section {
                    menuPicker("Center", selection: $ringCenterContent) {
                        Text("Nothing").tag(RingCenterContent.none)
                        Text("Time to reset").tag(RingCenterContent.remaining)
                        Text("Icon").tag(RingCenterContent.icon)
                    }
                } header: {
                    Text("Ring center")
                } footer: {
                    Text("What sits inside each ring. Bars keep icons and time beside the tracks.")
                }
            }
        }
    }

    private var accountTab: some View {
        settingsForm {
            Section {
                if store.isRefreshing {
                    Text("Refreshing…")
                        .foregroundStyle(.secondary)
                } else if let when = store.lastRefreshed {
                    LabeledContent("Last updated") {
                        Text(when.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Not refreshed yet")
                        .foregroundStyle(.secondary)
                }
                if let authError = store.authError {
                    Text(authError)
                        .foregroundStyle(.red)
                } else if let refreshError = store.refreshError {
                    Text(refreshError)
                        .foregroundStyle(.red)
                }
                Button("Refresh now") {
                    Task { await store.refresh() }
                }
                .disabled(store.isRefreshing)
            }

            Section {
                Button("Re-auth from Cursor") {
                    Task { await store.reauthFromCursor() }
                }
                Button("Paste token…") {
                    CursorAuthActions.promptPasteToken(into: store)
                }
                Button("Open Cursor Spending") {
                    NSWorkspace.shared.open(MenuPresenter.spendingURL)
                }
            } footer: {
                Text("Tokens stay in Keychain. Re-auth reads the signed-in Cursor app session when possible.")
            }
        }
    }

    private var paceTab: some View {
        settingsForm {
            Section {
                menuPicker("On-pace band", selection: deadZoneSelection) {
                    ForEach(Self.deadZonePresets, id: \.lo) { preset in
                        Text("\(preset.lo)–\(preset.hi)%").tag("\(preset.lo)-\(preset.hi)")
                    }
                }
            } footer: {
                Text("Colors and labels still use pace ratio r = used ÷ elapsed.")
            }
        }
    }

    private var alertsTab: some View {
        settingsForm {
            Section {
                Toggle("Blink on significant pace", isOn: $blinkSignificantPace)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("macOS notifications", isOn: $notifySignificantPace)
                        .onChange(of: notifySignificantPace) { _, enabled in
                            if enabled {
                                Task { await enableNotificationsAndDeliverIfNeeded() }
                            }
                        }
                    Button("Send test notification") {
                        Task {
                            let ok = await NotificationAlertService.deliver(
                                subject: "QuotAI: test alert",
                                body: "Notifications are working."
                            )
                            notifyStatus = ok
                                ? "Test notification sent."
                                : "Notification blocked — allow QuotAI in System Settings → Notifications."
                        }
                    }
                    if !notifyStatus.isEmpty {
                        Text(notifyStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Email alerts", isOn: $emailSignificantPace)
                    .onChange(of: emailSignificantPace) { _, enabled in
                        if enabled {
                            Task { await deliverAlertsNow(resetCooldown: true) }
                        }
                    }
            }

            Section {
                Toggle("Use smart pace alerts", isOn: $useSmartPaceAlerts)

                if useSmartPaceAlerts {
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Over-pace")
                                .font(.caption.weight(.semibold))
                                .padding(.bottom, 4)
                            HStack(alignment: .top, spacing: 2) {
                                PercentDial(
                                    title: "Max usage at period start",
                                    value: $overMaxStartPct,
                                    range: 0...50,
                                    tint: .orange,
                                    size: 32
                                )
                                PercentDial(
                                    title: "Full quota before",
                                    value: $overEmptyBeforePct,
                                    range: 50...100,
                                    tint: .orange,
                                    size: 32
                                )
                                PercentDial(
                                    title: "Curve (linear→parabolic)",
                                    value: $overCurvePct,
                                    range: 0...100,
                                    tint: .orange,
                                    size: 32
                                )
                            }

                            Text("Under-pace")
                                .font(.caption.weight(.semibold))
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                            HStack(alignment: .top, spacing: 2) {
                                PercentDial(
                                    title: "Under alerts after",
                                    value: $underAfterPct,
                                    range: 0...50,
                                    tint: .blue,
                                    size: 32
                                )
                                PercentDial(
                                    title: "Min usage by period end",
                                    value: $underMinEndPct,
                                    range: 50...100,
                                    tint: .blue,
                                    size: 32
                                )
                                PercentDial(
                                    title: "Curve (linear→parabolic)",
                                    value: $underCurvePct,
                                    range: 0...100,
                                    tint: .blue,
                                    size: 32
                                )
                            }
                        }
                        .fixedSize(horizontal: true, vertical: true)

                        Spacer(minLength: 0)

                        PaceAlertBandChart(thresholds: thresholds, meters: chartMeters)
                            .padding(.top, 7)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .onChange(of: overMaxStartPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: overEmptyBeforePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: overCurvePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underAfterPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underMinEndPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underCurvePct) { _, _ in scheduleCorridorAlertRecheck() }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Over alert if usage already exceeds “Max usage at period start” at the beginning of the billing period.")
                        Text("• Over alert if you reach 100% used before “Full quota before” share of the period has passed.")
                        Text("• Wait until “Under alerts after” share of the period has elapsed before considering an under alert.")
                        Text("• Under alert if usage would finish the period below “Min usage by period end”.")
                        Text("• Curve dials bend each corridor (0% linear → 100% parabolic). Under mirrors over across even pace; curves stay on the near side of parallels through Full quota before / Min usage by period end.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                } else {
                    menuPicker("Blink under", selection: $blinkUnderPercent) {
                        ForEach(Self.blinkUnderChoices, id: \.self) { pct in
                            Text("Below \(pct)% pace").tag(pct)
                        }
                    }
                    menuPicker("Blink over", selection: $blinkOverPercent) {
                        ForEach(Self.blinkOverChoices, id: \.self) { pct in
                            Text("Above \(pct)% pace").tag(pct)
                        }
                    }
                }
            }
        }
        .onAppear {
            guard notifySignificantPace || emailSignificantPace else { return }
            Task { await deliverAlertsNow(resetCooldown: false) }
        }
    }

    private var emailTab: some View {
        settingsForm {
            Section {
                TextField("SMTP host", text: $smtpHost)
                TextField("Port", value: $smtpPort, format: .number)
                Toggle("TLS (port 465)", isOn: $smtpUseTLS)
                TextField("Username", text: $smtpUsername)
                SecureField("Password", text: $smtpPassword)
                TextField("From", text: $smtpFrom)
                TextField("To", text: $smtpTo)
            }
            Section {
                if let emailStatus {
                    Text(emailStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Save password & send test") {
                    Task { await sendTestEmail() }
                }
            } footer: {
                Text("Use implicit TLS on port 465. STARTTLS on 587 is not supported yet.")
            }
        }
    }

    private var pinsTab: some View {
        settingsForm {
            Section {
                Toggle("Refresh interval", isOn: $pinRefreshInterval)
                Toggle("Menu bar style", isOn: $pinIconLook)
                Toggle("Color mode", isOn: $pinColorMode)
                Toggle("On-pace band", isOn: $pinOnPaceBand)
                Toggle("Show Other Models", isOn: $pinShowOtherModels)
                Toggle("Open Cursor Spending", isOn: $pinOpenCursorSpending)
            }
            Section {
                Toggle("Show icons", isOn: $pinShowAvatars)
                Toggle("Show used %", isOn: $pinShowUsedPercent)
                Toggle("Show elapsed %", isOn: $pinShowElapsedPercent)
                Toggle("Show time to reset", isOn: $pinShowRemaining)
                Toggle("Alternate elapsed % / time to reset", isOn: $pinAlternateElapsedRemaining)
            } header: {
                Text("Beside meter")
            } footer: {
                Text("Elapsed % and alternate apply to every ring style. Bars keep time to reset beside the tracks.")
            }
            Section {
                Toggle("Center content", isOn: $pinRingCenterContent)
            } header: {
                Text("Ring center")
            } footer: {
                Text("Ring styles only; ignored while Menu bar style is Bars.")
            }
            Section {
                Toggle("Blink toggle", isOn: $pinBlink)
            } footer: {
                Text("Pinned controls appear in the menu bar dropdown.")
            }
        }
    }

    /// Grouped form, switch toggles, content pinned to the top of the tab.
    private func settingsForm<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        Form {
            content()
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Label on the left; fixed-width menu control on the right.
    private func menuPicker<Selection: Hashable, Options: View>(
        _ title: String,
        selection: Binding<Selection>,
        @ViewBuilder options: () -> Options
    ) -> some View {
        LabeledContent(title) {
            Picker(title, selection: selection) {
                options()
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: Self.menuControlWidth, alignment: .trailing)
        }
    }

    private var deadZoneSelection: Binding<String> {
        Binding(
            get: { "\(paceOnLoPercent)-\(paceOnHiPercent)" },
            set: { tag in
                let parts = tag.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 2 else { return }
                paceOnLoPercent = parts[0]
                paceOnHiPercent = parts[1]
            }
        )
    }

    private func appendChartMeter(
        name: String,
        meter: QuotaMeter,
        into rows: inout [(String, Double, Double)]
    ) {
        guard !meter.isUnavailable,
              let used = meter.percentUsed,
              let start = meter.periodStart,
              let end = meter.periodEnd,
              let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end)
        else { return }
        rows.append((name, used, t * 100))
    }

    private func enableNotificationsAndDeliverIfNeeded() async {
        let granted = await NotificationAlertService.requestAuthorizationIfNeeded()
        if !granted {
            notifyStatus = "Notification blocked — allow QuotAI in System Settings → Notifications."
            return
        }
        await deliverAlertsNow(resetCooldown: true)
        if notifyStatus.isEmpty {
            notifyStatus = "Notifications enabled. Alerts fire on refresh when pace is significant."
        }
    }

    /// Dial drags update blink live; notify/email only run through the orchestrator.
    /// Debounce + clear cooldown so corridor simulation can fire a real alert.
    private func scheduleCorridorAlertRecheck() {
        guard notifySignificantPace || emailSignificantPace else { return }
        dialAlertTask?.cancel()
        dialAlertTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await deliverAlertsNow(resetCooldown: true)
        }
    }

    private func deliverAlertsNow(resetCooldown: Bool) async {
        if resetCooldown {
            UserDefaults.standard.removeObject(forKey: "paceAlertLastSignature")
            UserDefaults.standard.removeObject(forKey: "paceAlertLastDeliveredAt")
        }
        let result = await PaceAlertOrchestrator.handleSuccessfulRefresh(
            cursor: store.cursorModels,
            other: showOtherModels ? store.otherModels : nil,
            grok: store.grokBot
        )
        guard notifySignificantPace else { return }
        switch result {
        case .delivered:
            notifyStatus = "Pace alert notification sent."
        case .suppressedByCooldown:
            notifyStatus = "Pace alert on hold (same alert within the last hour)."
        case .quiet:
            break
        case .channelsOff:
            break
        case .failed:
            notifyStatus = "Pace alert notify failed — check System Settings → Notifications."
        }
    }

    private func sendTestEmail() async {
        do {
            try EmailAlertService.savePassword(smtpPassword)
            try await EmailAlertService.send(
                config: EmailAlertService.Config(
                    host: smtpHost,
                    port: smtpPort,
                    username: smtpUsername,
                    fromAddress: smtpFrom,
                    toAddress: smtpTo,
                    useTLS: smtpUseTLS
                ),
                subject: "QuotAI: test alert",
                body: "This is a QuotAI SMTP test message."
            )
            emailStatus = "Test email sent."
        } catch {
            emailStatus = error.localizedDescription
        }
    }
}

/// Menu-bar agent apps (LSUIElement) often create Settings behind other apps.
enum SettingsWindowElevator {
    static func show(_ open: () -> Void) {
        NSApp.setActivationPolicy(.regular)
        open()
        raise()
        DispatchQueue.main.async(execute: raise)
        // Menu dismissal can steal focus after the first raise.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: raise)
    }

    static func raise() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.styleMask.contains(.titled) {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

struct MenuSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            SettingsWindowElevator.show { openSettings() }
        }
    }
}
