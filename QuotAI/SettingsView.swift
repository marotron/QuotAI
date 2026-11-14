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

    @AppStorage("useSmartPaceAlerts") private var useSmartPaceAlerts = true
    @AppStorage("overMaxStartPct") private var overMaxStartPct = 25
    @AppStorage("overEmptyBeforePct") private var overEmptyBeforePct = 95
    @AppStorage("underAfterPct") private var underAfterPct = 25
    @AppStorage("underMinEndPct") private var underMinEndPct = 95
    @AppStorage("overCurvePct") private var overCurvePct = 0
    @AppStorage("underCurvePct") private var underCurvePct = 0
    @AppStorage("grokOverMaxStartPct") private var grokOverMaxStartPct = 35
    @AppStorage("grokOverEmptyBeforePct") private var grokOverEmptyBeforePct = 85
    @AppStorage("grokUnderAfterPct") private var grokUnderAfterPct = 40
    @AppStorage("grokUnderMinEndPct") private var grokUnderMinEndPct = 90
    @AppStorage("grokOverCurvePct") private var grokOverCurvePct = 20
    @AppStorage("grokUnderCurvePct") private var grokUnderCurvePct = 20
    @AppStorage("notifySignificantPace") private var notifySignificantPace = false
    @AppStorage("emailSignificantPace") private var emailSignificantPace = false

    @AppStorage("smtpHost") private var smtpHost = ""
    @AppStorage("smtpPort") private var smtpPort = 465
    @AppStorage("smtpUsername") private var smtpUsername = ""
    @AppStorage("smtpFrom") private var smtpFrom = ""
    @AppStorage("smtpTo") private var smtpTo = ""
    @AppStorage("smtpUseTLS") private var smtpUseTLS = true

    @AppStorage("pinRefreshAll") private var pinRefreshAll = true
    @AppStorage("pinRefreshCursor") private var pinRefreshCursor = false
    @AppStorage("pinRefreshGrok") private var pinRefreshGrok = false
    @AppStorage("pinRefreshInterval") private var pinRefreshInterval = true
    @AppStorage("pinColorMode") private var pinColorMode = false
    @AppStorage("pinIconLook") private var pinIconLook = false
    @AppStorage("pinShowOtherModels") private var pinShowOtherModels = false
    @AppStorage("pinShowAvatars") private var pinShowAvatars = false
    @AppStorage("pinShowPercent") private var pinShowUsedPercent = false
    @AppStorage("pinShowElapsedPercent") private var pinShowElapsedPercent = false
    @AppStorage("pinShowRemaining") private var pinShowRemaining = false
    @AppStorage("pinAlternateElapsedRemaining") private var pinAlternateElapsedRemaining = false
    @AppStorage("pinRingCenterContent") private var pinRingCenterContent = false
    @AppStorage("pinBlink") private var pinBlink = false
    @AppStorage("pinOpenCursorSpending") private var pinOpenCursorSpending = true
    @AppStorage("menuPinDensity") private var menuPinDensity: MenuPinDensity = .compact

    @State private var smtpPassword = ""
    @State private var emailStatus: String?
    @State private var notifyStatus = ""
    @State private var dialAlertTask: Task<Void, Never>?
    /// Ephemeral Settings focus — Cursor | Grok Bot corridor profile.
    @State private var alertFamilyFocus: PaceAlertFamily = .cursor

    /// Shared width for menu pickers so every dropdown control aligns on the right.
    private static let menuControlWidth: CGFloat = 180

    /// Alerts tab notes, shown in both corridor on and off states.
    private static let tintAndBlinkNotes = [
        "Tint and blink follow corridor under / over / exhausted only. Quiet or alerts off → neutral.",
        "Tint needs Color mode set to By pace. Blink works in any color mode."
    ]

    private var focusedThresholds: PaceAlertThresholds {
        PaceAlertThresholds(
            overMaxStartPct: Double(focusedOverMaxStartPct.wrappedValue),
            overEmptyBeforePct: Double(focusedOverEmptyBeforePct.wrappedValue),
            underAfterPct: Double(focusedUnderAfterPct.wrappedValue),
            underMinEndPct: Double(focusedUnderMinEndPct.wrappedValue),
            overCurvePct: Double(focusedOverCurvePct.wrappedValue),
            underCurvePct: Double(focusedUnderCurvePct.wrappedValue)
        )
    }

    private var focusedOverMaxStartPct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokOverMaxStartPct : $overMaxStartPct
    }

    private var focusedOverEmptyBeforePct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokOverEmptyBeforePct : $overEmptyBeforePct
    }

    private var focusedUnderAfterPct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokUnderAfterPct : $underAfterPct
    }

    private var focusedUnderMinEndPct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokUnderMinEndPct : $underMinEndPct
    }

    private var focusedOverCurvePct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokOverCurvePct : $overCurvePct
    }

    private var focusedUnderCurvePct: Binding<Int> {
        alertFamilyFocus == .grok ? $grokUnderCurvePct : $underCurvePct
    }

    private var focusedMeter: QuotaMeter {
        alertFamilyFocus == .grok ? store.grokBot : store.cursorModels
    }

    private var focusedPeriodLength: TimeInterval? {
        PeriodDuration.length(
            periodStart: focusedMeter.periodStart,
            periodEnd: focusedMeter.periodEnd
        )
    }

    private var focusedPeriodBadge: String? {
        focusedPeriodLength.map(PeriodDuration.badgeLabel(seconds:))
    }

    private var chartMeters: [PaceAlertBandChartMeter] {
        var rows: [PaceAlertBandChartMeter] = []
        appendChartMeter(name: "Cursor", meter: store.cursorModels, family: .cursor, into: &rows)
        if showOtherModels {
            appendChartMeter(name: "Other", meter: store.otherModels, family: .cursor, into: &rows)
        }
        appendChartMeter(name: "Grok Bot", meter: store.grokBot, family: .grok, into: &rows)
        return rows
    }

    private var besideMeterNotes: [String] {
        if iconLook == .bars {
            return [
                "Icons, used %, and time sit beside the tracks.",
                "With Color mode By pace, Show Other Models, and Show icons on, the Cursor icon slowly alternates when one of Models or Other is under and the other over."
            ]
        } else if iconLook == .ringsPerQuota, alternateElapsedRemaining {
            return [
                "Each meter has its own ring.",
                "One label blinks between elapsed % and time to reset (~5s).",
                "Used % still stacks above when enabled."
            ]
        } else if iconLook == .ringsPerQuota {
            return [
                "Each meter has its own ring.",
                "Used % and elapsed % stack beside it.",
                "Show Other Models adds its own ring.",
                "With Show icons on, the icon sits beside the ring, or inside it when Center is Icon."
            ]
        } else if alternateElapsedRemaining {
            return [
                "One label blinks between elapsed % and time to reset (~5s).",
                "Used % still stacks above when enabled."
            ]
        } else {
            return [
                "Used and elapsed together stack as two rows, or alone as one larger label.",
                "With Color mode By pace, Show Other Models, and Center set to Icon, the Cursor icon slowly alternates when one of Models or Other is under and the other over."
            ]
        }
    }

    var body: some View {
        TabView {
            displayTab.tabItem { Label("Display", systemImage: "paintpalette") }
            accountTab.tabItem { Label("Account", systemImage: "person.crop.circle") }
            refreshTab.tabItem { Label("Refresh", systemImage: "arrow.clockwise") }
            alertsTab.tabItem { Label("Alerts", systemImage: "bell") }
            emailTab.tabItem { Label("Email", systemImage: "envelope") }
            pinsTab.tabItem { Label("Menu pins", systemImage: "pin") }
        }
        .frame(width: 460, height: 620)
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
                    ForEach(IconLook.allCases, id: \.self) { look in
                        Text(look.pickerTitle).tag(look)
                    }
                }
                menuPicker("Color mode", selection: $iconColorMode) {
                    ForEach(IconColorMode.allCases, id: \.self) { mode in
                        Text(mode.pickerTitle).tag(mode)
                    }
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
                SettingsNotes(lines: besideMeterNotes)
            } header: {
                Text("Beside meter")
            }

            if iconLook != .bars {
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        menuPicker("Center", selection: $ringCenterContent) {
                            ForEach(RingCenterContent.allCases, id: \.self) { content in
                                Text(content.pickerTitle).tag(content)
                            }
                        }
                        SettingsNotes(lines: ["What sits inside each ring."])
                    }
                } header: {
                    Text("Ring center")
                }
            }
        }
    }

    private func clockComponent(_ time: Binding<Int>, hours: Bool) -> Binding<Int> {
        Binding(
            get: { hours ? time.wrappedValue / 60 : time.wrappedValue % 60 },
            set: { value in
                time.wrappedValue = hours
                    ? value * 60 + time.wrappedValue % 60
                    : time.wrappedValue / 60 * 60 + value
            }
        )
    }

    private var accountTab: some View {
        settingsForm {
            Section {
                if let authError = store.authError {
                    Text(authError)
                        .foregroundStyle(.red)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Button("Re-auth from Cursor") {
                        Task { await store.reauthFromCursor() }
                    }
                    SettingsNotes(lines: ["Reads the signed-in Cursor app session when possible."])
                }
                Button("Paste token…") {
                    CursorAuthActions.promptPasteToken(into: store)
                }
                Button("Open Cursor Spending") {
                    NSWorkspace.shared.open(MenuPresenter.spendingURL)
                }
                SettingsNotes(lines: ["Tokens stay in Keychain."])
            }

            Section {
                Toggle(
                    "Detect Cursor usage discrepancies",
                    isOn: $store.discrepancyDetectionEnabled
                )
                SettingsNotes(lines: [
                    "Reads local Cursor Agent Host logs and compares observed activity with the Cursor Models and Other Models quota meters.",
                    "QuotAI retains only deduplicated local activity from the current Cursor billing period."
                ])
                if store.discrepancyDetectionEnabled {
                    Toggle(
                        "Send macOS notifications",
                        isOn: $store.discrepancyNotificationsEnabled
                    )
                }
            } header: {
                Text("Cursor activity")
            }

        }
    }

    private var refreshTab: some View {
        settingsForm {
            Section {
                Text(store.lastRefreshStatusLine)
                    .foregroundStyle(.secondary)
                if let authError = store.authError {
                    Text(authError)
                        .foregroundStyle(.red)
                } else if let refreshError = store.refreshError {
                    Text(refreshError)
                        .foregroundStyle(.red)
                }
                VStack(alignment: .leading, spacing: 8) {
                    menuPicker("Refresh rate", selection: store.refreshEveryBinding()) {
                        ForEach(QuotaStore.pollIntervalChoices, id: \.self) { minutes in
                            Text(RefreshChoiceTitle.title(minutes: minutes)).tag(minutes)
                        }
                        Text("Dynamic").tag(QuotaStore.dynamicRefreshTag)
                    }
                    HStack(spacing: 8) {
                        Button("Refresh all") {
                            Task { await store.refresh(.all) }
                        }
                        Button("Refresh Cursor") {
                            Task { await store.refresh(.cursor) }
                        }
                        Button("Refresh Grok Bot") {
                            Task { await store.refresh(.grok) }
                        }
                    }
                    .disabled(store.isRefreshing)
                }
            }

            if store.dynamicRefresh {
                Section {
                    ForEach(store.refreshSchedule.steps.indices, id: \.self) { index in
                        ScheduleRuleRow {
                            scheduleChip(
                                title: "time to reset under",
                                minutes: scheduleUnderBinding(index)
                            )
                            Text("→")
                                .foregroundStyle(.secondary)
                            scheduleChip(
                                title: "refresh every",
                                minutes: scheduleEveryBinding(index)
                            )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    scheduleChip(
                        title: "otherwise refresh every",
                        minutes: scheduleOtherwiseBinding
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    SettingsNotes(lines: [
                        "Cursor and Grok each use this schedule, counted from their own next reset.",
                        "Rows are checked from the top, and the reset must be strictly under that row.",
                        "Intervals can't go below 1 minute.",
                        "If two rows share a threshold, the schedule resets to the default."
                    ])
                } header: {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Dynamic refresh")
                        Spacer(minLength: 8)
                        Button("Reset to default") {
                            store.refreshSchedule = .default
                        }
                        .font(.body.weight(.regular))
                        .disabled(store.refreshSchedule == .default)
                    }
                    .textCase(nil)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Automatic refresh") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Refresh on wake", isOn: $store.refreshOnWake)
                    Divider()
                    SettingsNotes(lines: [
                        "Refreshes Cursor and Grok Bot when your Mac wakes from sleep. On by default.",
                        "Runs during quiet hours when enabled. Turn this off to skip wake-triggered refreshes.",
                        "Turning this off does not pause scheduled polling outside quiet hours."
                    ])
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Quiet hours", isOn: $store.quietHoursEnabled)
                    if store.quietHoursEnabled {
                        ScheduleRuleRow {
                            clockChip(title: "from", time: $store.quietStartMinute)
                            Text("→").foregroundStyle(.secondary)
                            clockChip(title: "until", time: $store.quietEndMinute)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Divider()
                    SettingsNotes(lines: [
                        "Pauses scheduled polling, including Dynamic, high-usage and discrepancy-driven refreshes.",
                        "Manual refresh, opening a stale panel, and app launch can still refresh during quiet hours.",
                        "Refresh on wake also runs during quiet hours when its switch is on.",
                        "Uses your Mac’s local time and can cross midnight. Equal start and end times disable the quiet window."
                    ])
                }
            }

            Section("Refresh faster at high usage") {
                ForEach(0..<2, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(["Cursor Models + Other Models", "Grok Bot"][index], isOn: $store.thresholdRules[index].enabled)
                        if store.thresholdRules[index].enabled {
                            ScheduleRuleRow {
                                numberChip(title: "usage at or above", value: $store.thresholdRules[index].percent, range: 0...99, unit: "%")
                                Text("→").foregroundStyle(.secondary)
                                numberChip(title: "refresh every", value: $store.thresholdRules[index].minutes, range: 1...60, unit: "min")
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                SettingsNotes(lines: [
                    "A rule stays active until its quota resets. A current usage reading and reset time are required.",
                    "Either Cursor meter reaching the shared threshold activates their faster refresh. The fastest rule or normal schedule wins.",
                    "Quiet hours pause automatic polling; failed automatic requests wait at least 5 minutes before retrying."
                ])
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
                Toggle("Use corridor alerts", isOn: $useSmartPaceAlerts)

                if useSmartPaceAlerts {
                    corridorFamilyChrome

                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Over-pace")
                                .font(.caption.weight(.semibold))
                                .padding(.bottom, 4)
                            HStack(alignment: .top, spacing: 2) {
                                PercentDial(
                                    title: "Max usage at period start",
                                    value: focusedOverMaxStartPct,
                                    range: 0...50,
                                    tint: .orange,
                                    size: 32,
                                    periodLength: focusedPeriodLength
                                )
                                PercentDial(
                                    title: "Full quota before",
                                    value: focusedOverEmptyBeforePct,
                                    range: 50...100,
                                    tint: .orange,
                                    size: 32,
                                    periodLength: focusedPeriodLength,
                                    showsTimelineTip: true
                                )
                                PercentDial(
                                    title: "Curve (linear→parabolic)",
                                    value: focusedOverCurvePct,
                                    range: 0...100,
                                    tint: .orange,
                                    size: 32,
                                    periodLength: focusedPeriodLength
                                )
                            }

                            Text("Under-pace")
                                .font(.caption.weight(.semibold))
                                .padding(.top, 6)
                                .padding(.bottom, 4)
                            HStack(alignment: .top, spacing: 2) {
                                PercentDial(
                                    title: "Under alerts after",
                                    value: focusedUnderAfterPct,
                                    range: 0...50,
                                    tint: .blue,
                                    size: 32,
                                    periodLength: focusedPeriodLength,
                                    showsTimelineTip: true
                                )
                                PercentDial(
                                    title: "Min usage by period end",
                                    value: focusedUnderMinEndPct,
                                    range: 50...100,
                                    tint: .blue,
                                    size: 32,
                                    periodLength: focusedPeriodLength
                                )
                                PercentDial(
                                    title: "Curve (linear→parabolic)",
                                    value: focusedUnderCurvePct,
                                    range: 0...100,
                                    tint: .blue,
                                    size: 32,
                                    periodLength: focusedPeriodLength
                                )
                            }
                        }
                        .fixedSize(horizontal: true, vertical: true)

                        Spacer(minLength: 0)

                        PaceAlertBandChart(
                            thresholds: focusedThresholds,
                            meters: chartMeters,
                            focusPeriodLength: focusedPeriodLength,
                            focusFamily: alertFamilyFocus
                        )
                        .padding(.top, 7)
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                    .onChange(of: overMaxStartPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: overEmptyBeforePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: overCurvePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underAfterPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underMinEndPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: underCurvePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokOverMaxStartPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokOverEmptyBeforePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokOverCurvePct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokUnderAfterPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokUnderMinEndPct) { _, _ in scheduleCorridorAlertRecheck() }
                    .onChange(of: grokUnderCurvePct) { _, _ in scheduleCorridorAlertRecheck() }

                    SettingsNotes(lines: [
                        "Over alert when usage is above the over line. The line starts at “Max usage at period start” and reaches 100% at “Full quota before”.",
                        "Exhausted when usage reaches 100%, at any point in the period.",
                        "Wait until “Under alerts after” share of the period has elapsed before considering an under alert.",
                        "Under alert if usage would finish the period below “Min usage by period end”.",
                        "Curve dials bend each corridor (0% linear → 100% parabolic). Under mirrors over across even pace; curves stay on the near side of parallels through Full quota before / Min usage by period end.",
                        alertFamilyFocus == .cursor
                            ? "Editing Cursor profile (Models + Other). Switch to Grok Bot for the short window."
                            : "Editing Grok Bot profile. Cursor dials are unchanged.",
                        "Period length (the days badge) comes from each family’s live usage API window — Cursor billing cycle start→end, Grok Bot period start→reset. Cursor months can be 28–31 days; do not assume a fixed 31. Dial and chart day/hour tips use that same duration.",
                        "Drag any dial: tooltip shows the %. “Full quota before” / “Under alerts after” also show elapsed + time left to reset (days, or hours on short periods).",
                        "Hover the preview chart: Used % stays; elapsed becomes time left to reset (days, or hours when under a day) for the focused family."
                    ] + Self.tintAndBlinkNotes)
                } else {
                    SettingsNotes(lines: [
                        "Corridor alerts off — ring/bar stay neutral; panel alert icons stay empty."
                    ] + Self.tintAndBlinkNotes)
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
                VStack(alignment: .leading, spacing: 0) {
                    Toggle("TLS (port 465)", isOn: $smtpUseTLS)
                    SettingsNotes(lines: [
                        "Use implicit TLS on port 465.",
                        "STARTTLS on 587 is not supported yet."
                    ])
                }
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
            }
        }
    }

    private var pinsTab: some View {
        settingsForm {
            Section {
                VStack(alignment: .leading, spacing: 0) {
                    menuPicker("Dropdown layout", selection: $menuPinDensity) {
                        ForEach(MenuPinDensity.allCases, id: \.self) { density in
                            Text(density.pickerTitle).tag(density)
                        }
                    }
                    SettingsNotes(lines: [
                        "Compact: smaller text, pinned rows in two columns.",
                        "Normal: regular text, one column."
                    ])
                }
            }
            Section {
                Toggle("Refresh all", isOn: $pinRefreshAll)
                Toggle("Refresh Cursor", isOn: $pinRefreshCursor)
                Toggle("Refresh Grok Bot", isOn: $pinRefreshGrok)
                Toggle("Refresh interval", isOn: $pinRefreshInterval)
                Toggle("Open Cursor Spending", isOn: $pinOpenCursorSpending)
            }
            Section {
                Toggle("Style", isOn: $pinIconLook)
                Toggle("Color mode", isOn: $pinColorMode)
                Toggle("Show Other Models", isOn: $pinShowOtherModels)
                VStack(alignment: .leading, spacing: 0) {
                    Toggle("Ring center", isOn: $pinRingCenterContent)
                    SettingsNotes(lines: [
                        "Ring center applies to ring styles only; ignored while Style is Bars."
                    ])
                }
            } header: {
                Text("Menu bar · Display")
            }
            Section {
                Toggle("Show icons", isOn: $pinShowAvatars)
                Toggle("Show used %", isOn: $pinShowUsedPercent)
                Toggle("Show elapsed %", isOn: $pinShowElapsedPercent)
                Toggle("Show time to reset", isOn: $pinShowRemaining)
                Toggle("Alternate elapsed % / time to reset", isOn: $pinAlternateElapsedRemaining)
                SettingsNotes(lines: [
                    "Elapsed % and alternate apply to every ring style.",
                    "Bars keep time to reset beside the tracks."
                ])
            } header: {
                Text("Menu bar · Beside meter")
            }
            Section {
                Toggle("Blink on significant pace", isOn: $pinBlink)
            } header: {
                Text("Alerts")
            } footer: {
                // Tab-level note: sits below the last card.
                SettingsNotes(lines: [
                    "Pinned controls appear in the menu bar dropdown."
                ])
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


    private func clockChip(title: String, time: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 3) {
                DragNumberField(value: clockComponent(time, hours: true), range: 0...23, label: "Quiet hours \(title) hour", padded: true)
                Text(":").foregroundStyle(.secondary)
                DragNumberField(value: clockComponent(time, hours: false), range: 0...59, label: "Quiet hours \(title) minute", padded: true)
            }
        }
        .padding(.horizontal, 4)
        .scheduleChipStyle()
    }

    private func numberChip(title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            DragNumberField(value: value, range: range, label: title)
            Text(unit)
        }
        .scheduleChipStyle()
    }

    private func scheduleChip(title: String, minutes: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            ScheduleDurationField(minutes: minutes, label: title)
        }
        .scheduleChipStyle()
    }

    private func scheduleUnderBinding(_ index: Int) -> Binding<Int> {
        scheduleStepBinding(index, keyPath: \.underMinutes)
    }

    private func scheduleEveryBinding(_ index: Int) -> Binding<Int> {
        scheduleStepBinding(index, keyPath: \.everyMinutes)
    }

    private func scheduleStepBinding(
        _ index: Int,
        keyPath: WritableKeyPath<RefreshSchedule.Step, Int>
    ) -> Binding<Int> {
        Binding(
            get: {
                guard store.refreshSchedule.steps.indices.contains(index) else { return 1 }
                return store.refreshSchedule.steps[index][keyPath: keyPath]
            },
            set: { newValue in
                var schedule = store.refreshSchedule
                guard schedule.steps.indices.contains(index) else { return }
                let clamped = max(1, newValue)
                guard schedule.steps[index][keyPath: keyPath] != clamped else { return }
                schedule.steps[index][keyPath: keyPath] = clamped
                store.refreshSchedule = schedule
            }
        )
    }

    private var scheduleOtherwiseBinding: Binding<Int> {
        Binding(
            get: { store.refreshSchedule.otherwiseMinutes },
            set: { newValue in
                var schedule = store.refreshSchedule
                let clamped = max(1, newValue)
                guard schedule.otherwiseMinutes != clamped else { return }
                schedule.otherwiseMinutes = clamped
                store.refreshSchedule = schedule
            }
        )
    }

    private var corridorFamilyChrome: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Corridor family", selection: $alertFamilyFocus) {
                Label {
                    Text("Cursor")
                } icon: {
                    Image(nsImage: BarIcon.tintedAvatar(
                        .cursor,
                        ink: NSColor.labelColor,
                        pointSize: 12
                    ))
                }
                .tag(PaceAlertFamily.cursor)

                Label {
                    Text("Grok Bot")
                } icon: {
                    Image(nsImage: BarIcon.tintedAvatar(
                        .grok,
                        ink: NSColor.labelColor,
                        pointSize: 12
                    ))
                }
                .tag(PaceAlertFamily.grok)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Corridor family")

            HStack(spacing: 6) {
                Text("Period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let focusedPeriodBadge {
                    Text(focusedPeriodBadge)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5)
                        )
                } else {
                    Text("—")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if alertFamilyFocus == .cursor {
                    Text("· Models + Other share this profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.top, 2)
    }

    private func appendChartMeter(
        name: String,
        meter: QuotaMeter,
        family: PaceAlertFamily,
        into rows: inout [PaceAlertBandChartMeter]
    ) {
        guard !meter.isUnavailable,
              let used = meter.percentUsed,
              let start = meter.periodStart,
              let end = meter.periodEnd,
              let t = PaceCalculator.elapsedFraction(periodStart: start, periodEnd: end)
        else { return }
        rows.append(PaceAlertBandChartMeter(
            name: name,
            usedPct: used,
            elapsedPct: t * 100,
            family: family
        ))
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

/// Left chip at the leading edge, right chip at the trailing edge, arrow in the middle of the gap.
private struct ScheduleRuleRow: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let height = sizes.map(\.height).max() ?? 0
        let minWidth = sizes.map(\.width).reduce(0, +)
        return CGSize(width: max(proposal.width ?? minWidth, minWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let left = subviews[0].sizeThatFits(.unspecified)
        let arrow = subviews[1].sizeThatFits(.unspecified)
        let right = subviews[2].sizeThatFits(.unspecified)

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(left)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(right)
        )
        let gapMidX = bounds.minX + left.width + (bounds.width - left.width - right.width) / 2
        subviews[1].place(
            at: CGPoint(x: gapMidX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(arrow)
        )
    }
}

/// Bulleted note rows, styled like the corridor alert notes on the Alerts tab.
private struct SettingsNotes: View {
    var lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(lines, id: \.self) { line in
                Text(verbatim: "• \(line)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

/// Minute span edited as a number plus min / hr / day. Writes through on commit, not each keystroke.
private struct ScheduleDurationField: View {
    @Binding var minutes: Int
    var label: String

    @State private var unit: RefreshUnit
    @State private var draft: String
    @State private var focused = false
    @State private var dragging = false

    init(minutes: Binding<Int>, label: String) {
        _minutes = minutes
        self.label = label
        let fitted = RefreshDuration.fitting(minutes.wrappedValue)
        _unit = State(initialValue: fitted.unit)
        _draft = State(initialValue: String(fitted.count))
    }

    var body: some View {
        HStack(spacing: 2) {
            NativeDragNumberField(
                value: Binding(
                    get: { Self.parse(draft) ?? 1 },
                    set: { count in draft = String(count); commitDraft() }
                ),
                range: 1...100_000, label: "\(label) amount",
                onFocus: { focused = $0 }, onDrag: { dragging = $0 }
            )
            .frame(width: max(42, CGFloat(String(Self.parse(draft) ?? 1).count) * 9 + 18), height: 22)
            Picker("\(label) unit", selection: unitSelection) {
                ForEach(RefreshUnit.allCases, id: \.self) { choice in
                    Text(choice.title(count: Self.parse(draft) ?? 1)).tag(choice)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
        .fixedSize(horizontal: true, vertical: false)
        .onChange(of: minutes) { _, newValue in
            guard !focused, !dragging else { return }
            let shown = RefreshDuration(count: Self.parse(draft) ?? 1, unit: unit).minutes
            guard shown != newValue else { return }
            apply(RefreshDuration.fitting(newValue))
        }
    }

    private var unitSelection: Binding<RefreshUnit> {
        Binding(
            get: { unit },
            set: { newUnit in
                guard newUnit != unit else { return }
                let base = Self.parse(draft).map { RefreshDuration(count: $0, unit: unit) }
                    ?? RefreshDuration.fitting(minutes)
                let converted = base.converted(to: newUnit)
                apply(converted)
                if minutes != converted.minutes { minutes = converted.minutes }
            }
        )
    }

    private func apply(_ duration: RefreshDuration) {
        unit = duration.unit
        draft = String(duration.count)
    }

    private func commitDraft() {
        guard let count = Self.parse(draft) else {
            apply(RefreshDuration.fitting(minutes))
            return
        }
        draft = String(count)
        let next = RefreshDuration(count: count, unit: unit).minutes
        if minutes != next { minutes = next }
    }

    private static func parse(_ draft: String) -> Int? {
        guard let value = Int(draft.trimmingCharacters(in: .whitespaces)), value >= 1 else {
            return nil
        }
        return min(value, 100_000)
    }
}

private extension View {
    func scheduleChipStyle() -> some View {
        self.padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
            .fixedSize()
    }
}

private struct DragNumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    var padded = false

    var body: some View {
        NativeDragNumberField(value: $value, range: range, label: label, padded: padded)
            .frame(width: max(42, CGFloat(String(range.upperBound).count) * 9 + 18), height: 22)
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
        // Only already-visible titled windows — closed About/Changelog hosts stay
        // in NSApp.windows (`isReleasedWhenClosed = false`) and must not resurrect.
        for window in NSApp.windows where window.styleMask.contains(.titled) && window.isVisible {
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
