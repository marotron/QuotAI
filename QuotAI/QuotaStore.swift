import AppKit
import Combine
import Foundation
import QuotAICore
import SwiftUI

@MainActor
final class QuotaStore: ObservableObject {
    enum RefreshScope: Equatable {
        case all
        case cursor
        case grok
    }

    @Published var cursorModels = QuotaMeter(name: "Cursor Models")
    @Published var otherModels = QuotaMeter(name: "Other Models", isUnavailable: true)
    @Published var grokBot = QuotaMeter(name: "Grok Bot", isUnavailable: true)
    /// Sign-in failure. Replaces the menu-bar icon until re-auth works.
    @Published var authError: String?
    /// Last fetch failed. Shown in the menu; the rings stay up with the previous meters.
    @Published var refreshError: String?
    @Published var isRefreshing = false
    /// Which family (or `.all`) is mid-refresh; drives badge spin without blanking the status row.
    @Published private(set) var refreshingScope: RefreshScope?
    @Published var lastCursorRefreshed: Date?
    @Published var lastGrokRefreshed: Date?
    /// Dropdown + menu-bar reset countdown. Moves at most once a minute.
    @Published private(set) var displayClock = Date()
    /// Bumps when pace-history samples are written so the window panel can redraw.
    @Published private(set) var paceHistoryEpoch = 0
    /// Current billing-period detector events, published for the panel.
    @Published private(set) var cursorDiscrepancyEvents: [CursorDiscrepancyEvent] = []

    let paceHistoryStore: PaceHistorySampleStore
    let cursorActivityStore: CursorActivityStore
    private let cursorLogActivityReader: CursorLogActivityReader

    #if PANEL_PREVIEW
        /// Set only by the design-preview initializer; short-circuits every fetch path so
        /// the preview app stays look-only. Compiled out of production builds.
        private let isPreview: Bool
    #endif

    private var didAttemptAuthFailureReimport = false
    private var pollTimer: Timer?
    private var displayClockTimer: Timer?
    private var pollActivity: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    /// Next scheduled poll fire; minute clock reschedules when the planner moves this.
    private var scheduledPollFire: Date?

    static let pollIntervalChoices = [5, 10, 15, 30, 60]
    /// Menu tag for the dynamic schedule. Not stored as `pollIntervalMinutes`.
    static let dynamicRefreshTag = 0
    private static let pollIntervalKey = "pollIntervalMinutes"
    private static let dynamicRefreshKey = "dynamicRefresh"
    private static let refreshScheduleKey = "refreshSchedule"
    private static let discrepancyDetectionKey = "detectCursorUsageDiscrepancies"
    private static let discrepancyNotificationsKey = "notifyCursorUsageDiscrepancies"
    private static let discrepancyNotificationSignatureKey = "cursorDiscrepancyNotificationSignature"

    private var detectorHasRecentTurn: Bool {
        guard discrepancyDetectionEnabled,
              let latest = cursorActivityStore.state.turns.last(where: { !$0.isOutsideCursorBilling })?.timestamp
        else {
            return false
        }
        return Date() <= latest.addingTimeInterval(CursorDiscrepancyReconciler.graceWindow)
    }

    /// Fixed auto-refresh interval, kept so turning Dynamic off restores it.
    @Published var pollIntervalMinutes: Int {
        didSet {
            guard pollIntervalMinutes != oldValue else { return }
            UserDefaults.standard.set(pollIntervalMinutes, forKey: Self.pollIntervalKey)
            if !dynamicRefresh {
                startPolling(refreshNow: false)
            }
        }
    }

    /// When set, cadence comes from `refreshSchedule` instead of `pollIntervalMinutes`.
    @Published var dynamicRefresh: Bool {
        didSet {
            guard dynamicRefresh != oldValue else { return }
            UserDefaults.standard.set(dynamicRefresh, forKey: Self.dynamicRefreshKey)
            startPolling(refreshNow: false)
        }
    }

    @Published var refreshSchedule: RefreshSchedule {
        didSet {
            guard refreshSchedule != oldValue else { return }
            guard let data = try? JSONEncoder().encode(refreshSchedule) else { return }
            let stored = RefreshSchedule.fromStoredJSON(data)
            if stored != refreshSchedule {
                refreshSchedule = stored
                return
            }
            UserDefaults.standard.set(data, forKey: Self.refreshScheduleKey)
            if dynamicRefresh {
                startPolling(refreshNow: false)
            }
        }
    }

    @Published var discrepancyDetectionEnabled: Bool {
        didSet {
            guard discrepancyDetectionEnabled != oldValue else { return }
            UserDefaults.standard.set(discrepancyDetectionEnabled, forKey: Self.discrepancyDetectionKey)
            if discrepancyDetectionEnabled,
               UserDefaults.standard.object(forKey: Self.discrepancyNotificationsKey) == nil {
                discrepancyNotificationsEnabled = true
            }
            if discrepancyDetectionEnabled {
                Task { await refresh(.cursor) }
            }
            startPolling(refreshNow: false)
        }
    }

    @Published var discrepancyNotificationsEnabled: Bool {
        didSet {
            guard discrepancyNotificationsEnabled != oldValue else { return }
            UserDefaults.standard.set(discrepancyNotificationsEnabled, forKey: Self.discrepancyNotificationsKey)
        }
    }

    /// Picker tag: `dynamicRefreshTag` or a fixed minute choice.
    var refreshEveryTag: Int {
        get { dynamicRefresh ? Self.dynamicRefreshTag : pollIntervalMinutes }
        set {
            if newValue == Self.dynamicRefreshTag {
                dynamicRefresh = true
            } else if Self.pollIntervalChoices.contains(newValue) {
                if pollIntervalMinutes != newValue {
                    pollIntervalMinutes = newValue
                }
                dynamicRefresh = false
            }
        }
    }

    func refreshEveryBinding() -> Binding<Int> {
        Binding(
            get: { self.refreshEveryTag },
            set: { self.refreshEveryTag = $0 }
        )
    }

    /// Menu + Settings status line (24-hour times).
    var lastRefreshStatusLine: String {
        LastRefreshStatus.line(
            cursor: lastCursorRefreshed,
            grok: lastGrokRefreshed,
            isRefreshing: isRefreshing,
            formatTime: { LastRefreshStatus.format24Hour($0) }
        )
    }

    init() {
        #if PANEL_PREVIEW
            isPreview = false
        #endif
        paceHistoryStore = PaceHistorySampleStore()
        cursorActivityStore = CursorActivityStore()
        cursorLogActivityReader = CursorLogActivityReader()
        let stored = UserDefaults.standard.integer(forKey: Self.pollIntervalKey)
        pollIntervalMinutes = Self.pollIntervalChoices.contains(stored) ? stored : 10
        dynamicRefresh = UserDefaults.standard.bool(forKey: Self.dynamicRefreshKey)
        if let data = UserDefaults.standard.data(forKey: Self.refreshScheduleKey) {
            refreshSchedule = RefreshSchedule.fromStoredJSON(data)
        } else {
            refreshSchedule = .default
        }
        discrepancyDetectionEnabled = UserDefaults.standard.bool(forKey: Self.discrepancyDetectionKey)
        discrepancyNotificationsEnabled = UserDefaults.standard.object(forKey: Self.discrepancyNotificationsKey) == nil
            || UserDefaults.standard.bool(forKey: Self.discrepancyNotificationsKey)
        if discrepancyDetectionEnabled {
            cursorDiscrepancyEvents = cursorActivityStore.state.events
        }
        startPolling(refreshNow: true)
        startDisplayClock()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh(.all) }
        }
    }

    #if PANEL_PREVIEW
        /// Design-preview store: believable meters and history for the panel preview app.
        /// No timers, no network, no keychain; history goes to a throwaway temp file so the
        /// real app's `pace-history.json` is never touched.
        init(previewHistoryFileURL: URL) {
            isPreview = true
            paceHistoryStore = PaceHistorySampleStore(fileURL: previewHistoryFileURL)
            cursorActivityStore = CursorActivityStore(
                fileURL: previewHistoryFileURL.deletingLastPathComponent().appendingPathComponent("cursor-activity.json")
            )
            cursorLogActivityReader = CursorLogActivityReader()
            pollIntervalMinutes = 10
            dynamicRefresh = false
            refreshSchedule = .default
            discrepancyDetectionEnabled = false
            discrepancyNotificationsEnabled = true

            let now = Date()
            let periodStart = Calendar.current.date(byAdding: .day, value: -25, to: now) ?? now
            let periodEnd = Calendar.current.date(byAdding: .day, value: 5, to: now) ?? now
            // Tweak these to exercise panel states: on-corridor / under / exhausted.
            cursorModels = QuotaMeter(
                name: "Cursor Models",
                percentUsed: 72,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            otherModels = QuotaMeter(
                name: "Other Models",
                percentUsed: 45,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            grokBot = QuotaMeter(
                name: "Grok Bot",
                percentUsed: 104,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
            lastCursorRefreshed = now.addingTimeInterval(-4 * 60)
            lastGrokRefreshed = now.addingTimeInterval(-4 * 60)
            Self.seedPreviewHistory(
                into: paceHistoryStore,
                periodStart: periodStart,
                periodEnd: periodEnd
            )
        }

        /// One gentle ramp per series so the chart well shows three trajectories.
        private static func seedPreviewHistory(
            into store: PaceHistorySampleStore,
            periodStart: Date,
            periodEnd: Date
        ) {
            let finals: [(id: PaceHistoryMeterId, usedPct: Double)] = [
                (.cursor, 72), (.other, 45), (.grok, 104)
            ]
            let duration = periodEnd.timeIntervalSince(periodStart)
            var batch: [PaceHistorySample] = []
            for (id, final) in finals {
                let count = 16
                for step in 0..<count {
                    let t = Double(step) / Double(count - 1)
                    // Ease-in ramp toward the meter's current used %.
                    let used = final * (0.15 + 0.85 * t * t)
                    batch.append(
                        PaceHistorySample(
                            meterId: id,
                            usedPct: min(used, final),
                            elapsedPct: t * 83.3, // 25 of 30 days elapsed
                            timestamp: periodStart.addingTimeInterval(t * duration * 0.83),
                            periodStart: periodStart
                        )
                    )
                }
            }
            try? store.append(contentsOf: batch)
        }
    #endif

    deinit {
        pollTimer?.invalidate()
        displayClockTimer?.invalidate()
        if let pollActivity { ProcessInfo.processInfo.endActivity(pollActivity) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    /// Align the countdown to now. Used when the menu opens, between minute ticks.
    func snapDisplayClock() {
        displayClock = Date()
    }

    /// Next fire is the following wall-clock minute, then every 60s, including while a menu is tracking.
    private func startDisplayClock() {
        displayClockTimer?.invalidate()
        let timer = Timer(fire: Self.nextMinute(), interval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.displayClock = Date()
                self?.restartPollingIfFireChanged()
            }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        displayClockTimer = timer
    }

    private static func nextMinute(after now: Date = Date()) -> Date {
        let seconds = now.timeIntervalSince1970
        let boundary = ceil(seconds / 60) * 60
        let fire = boundary <= seconds + 0.05 ? boundary + 60 : boundary
        return Date(timeIntervalSince1970: fire)
    }

    /// One-shot timer to the planner’s next fire; Dynamic may refresh only due families.
    private func startPolling(refreshNow: Bool) {
        if let pollActivity {
            ProcessInfo.processInfo.endActivity(pollActivity)
            self.pollActivity = nil
        }

        pollActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "QuotAI quota polling"
        )

        scheduleNextPoll()

        if refreshNow {
            Task { await self.refresh(.all) }
        }
    }

    private func scheduleNextPoll() {
        pollTimer?.invalidate()
        let now = Date()
        let fire = plannerNextFire(now: now)
        scheduledPollFire = fire
        let delay = max(1, fire.timeIntervalSince(now))
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handlePollTimer()
            }
        }
        timer.tolerance = min(30, delay * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func handlePollTimer() async {
        if detectorHasRecentTurn {
            await refresh(.cursor)
        } else if dynamicRefresh {
            let due = plannerDueFamilies(now: Date())
            if due.contains(.cursor) && due.contains(.grok) {
                await refresh(.all)
            } else if due.contains(.cursor) {
                await refresh(.cursor)
            } else if due.contains(.grok) {
                await refresh(.grok)
            }
        } else {
            await refresh(.all)
        }
        scheduleNextPoll()
    }

    private var cursorPeriodEnds: [Date] {
        [cursorModels.periodEnd, otherModels.periodEnd].compactMap { $0 }
    }

    private var grokPeriodEnds: [Date] {
        [grokBot.periodEnd].compactMap { $0 }
    }

    private func plannerDueFamilies(now: Date) -> [RefreshFamily] {
        RefreshPlanner.dueFamilies(
            dynamic: dynamicRefresh,
            fixedMinutes: pollIntervalMinutes,
            schedule: refreshSchedule,
            cursorPeriodEnds: cursorPeriodEnds,
            grokPeriodEnds: grokPeriodEnds,
            lastCursor: lastCursorRefreshed,
            lastGrok: lastGrokRefreshed,
            now: now
        )
    }

    private func plannerNextFire(now: Date) -> Date {
        let planned = RefreshPlanner.nextFire(
            dynamic: dynamicRefresh,
            fixedMinutes: pollIntervalMinutes,
            schedule: refreshSchedule,
            cursorPeriodEnds: cursorPeriodEnds,
            grokPeriodEnds: grokPeriodEnds,
            lastCursor: lastCursorRefreshed,
            lastGrok: lastGrokRefreshed,
            now: now
        )
        guard detectorHasRecentTurn else { return planned }
        return min(planned, now.addingTimeInterval(60))
    }

    /// Minute clock and a finished fetch retune the timer without an extra request.
    private func restartPollingIfFireChanged() {
        let fire = plannerNextFire(now: Date())
        if let scheduledPollFire, abs(scheduledPollFire.timeIntervalSince(fire)) < 0.5 {
            return
        }
        scheduleNextPoll()
    }

    /// Pull families that are stale by their own interval (or never fetched).
    func refreshIfStale() async {
        let due = plannerDueFamilies(now: Date())
        if due.isEmpty { return }
        if due.contains(.cursor) && due.contains(.grok) {
            await refresh(.all)
        } else if due.contains(.cursor) {
            await refresh(.cursor)
        } else {
            await refresh(.grok)
        }
    }

    func refresh(_ scope: RefreshScope = .all, forceReimport: Bool = false) async {
        #if PANEL_PREVIEW
            if isPreview { return }
        #endif
        guard !isRefreshing else { return }
        isRefreshing = true
        refreshingScope = scope
        authError = nil
        refreshError = nil
        defer {
            isRefreshing = false
            refreshingScope = nil
        }

        do {
            try await fetchAndApply(scope: scope, forceReimport: forceReimport)
        } catch CursorConnectClient.ClientError.unauthorized,
                CursorConnectClient.ClientError.shouldLogout,
                CursorConnectClient.ClientError.refreshFailed {
            await handleAuthFailure(scope: scope)
        } catch {
            refreshError = Self.refreshFailureMessage(error)
        }
    }

    /// Current poll interval seconds for a single family (dynamic schedule or fixed minutes).
    func pollIntervalSeconds(for family: RefreshFamily, now: Date = Date()) -> TimeInterval {
        let ends: [Date]
        switch family {
        case .cursor: ends = cursorPeriodEnds
        case .grok: ends = grokPeriodEnds
        }
        return RefreshPlanner.interval(
            dynamic: dynamicRefresh,
            fixedMinutes: pollIntervalMinutes,
            schedule: refreshSchedule,
            periodEnds: ends,
            now: now
        )
    }

    func isRefreshingFamily(_ family: RefreshFamily) -> Bool {
        switch refreshingScope {
        case .all: return true
        case .cursor: return family == .cursor
        case .grok: return family == .grok
        case nil: return false
        }
    }

    func reauthFromCursor() async {
        didAttemptAuthFailureReimport = false
        await refresh(.all, forceReimport: true)
    }

    func pasteAccessToken(_ accessToken: String, refreshToken: String?) {
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let refreshTrimmed = (refreshToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let refreshValue = refreshTrimmed.isEmpty ? trimmed : refreshTrimmed
        if CursorSealedToken.isSealed(trimmed) || CursorSealedToken.isSealed(refreshValue) {
            authError = "Paste a JWT — not a sealed Cursor storage value"
            return
        }
        let creds = QuotAIKeychain.Credentials(
            accessToken: trimmed,
            refreshToken: refreshValue
        )
        do {
            try KeychainStore.save(creds)
            authError = nil
            refreshError = nil
            Task { await self.refresh(.all) }
        } catch {
            authError = "Could not save token"
        }
    }

    private func resolveCredentials(forceReimport: Bool) async throws -> QuotAIKeychain.Credentials {
        if !forceReimport, let existing = try KeychainStore.load(), !Self.containsSealedToken(existing) {
            return existing
        }
        if let imported = try CursorVscdbImporter.importCredentials() {
            try KeychainStore.save(imported)
            return imported
        }
        if let existing = try KeychainStore.load(), !Self.containsSealedToken(existing) {
            return existing
        }
        // Prior import may have saved sealed ciphertext; drop it so Re-auth can recover.
        if (try? KeychainStore.load()).map(Self.containsSealedToken) == true {
            try? KeychainStore.clear()
        }
        throw CursorConnectClient.ClientError.unauthorized
    }

    private static func containsSealedToken(_ credentials: QuotAIKeychain.Credentials) -> Bool {
        CursorSealedToken.isSealed(credentials.accessToken)
            || CursorSealedToken.isSealed(credentials.refreshToken)
    }

    private func connectScope(for scope: RefreshScope) -> CursorConnectClient.FetchScope {
        switch scope {
        case .all: return .all
        case .cursor: return .cursor
        case .grok: return .grok
        }
    }

    private func fetchAndApply(scope: RefreshScope, forceReimport: Bool) async throws {
        let credentials = try await resolveCredentials(forceReimport: forceReimport)
        let result = try await CursorConnectClient.fetchMeters(
            credentials: credentials,
            scope: connectScope(for: scope)
        )
        try KeychainStore.save(result.credentials)
        let stamp = Date()
        var historyBatch: [PaceHistorySample] = []
        if let cursor = result.cursorModels {
            cursorModels = cursor
            lastCursorRefreshed = stamp
            if let sample = Self.paceHistorySample(meterId: .cursor, meter: cursor, now: stamp) {
                historyBatch.append(sample)
            }
        }
        if let other = result.otherModels {
            otherModels = other
            if let sample = Self.paceHistorySample(meterId: .other, meter: other, now: stamp) {
                historyBatch.append(sample)
            }
        }
        if let grok = result.grokBot {
            grokBot = grok
            lastGrokRefreshed = stamp
            if let sample = Self.paceHistorySample(meterId: .grok, meter: grok, now: stamp) {
                historyBatch.append(sample)
            }
        }
        if !historyBatch.isEmpty {
            try? paceHistoryStore.append(contentsOf: historyBatch)
            paceHistoryEpoch &+= 1
        }
        if scope == .all || scope == .cursor {
            // Do not await: Agent Host log scan must not stall meters / Keychain return.
            scheduleCursorDiscrepancyDetector(at: stamp, accessToken: result.credentials.accessToken)
        }
        authError = nil
        refreshError = nil
        didAttemptAuthFailureReimport = false
        restartPollingIfFireChanged()
        let includeOther = UserDefaults.standard.bool(forKey: "showOtherModels")
        await PaceAlertOrchestrator.handleSuccessfulRefresh(
            cursor: cursorModels,
            other: includeOther ? otherModels : nil,
            grok: grokBot
        )
    }

    /// Sample for a successful meter update when used %, elapsed %, and period start are present.
    private static func paceHistorySample(
        meterId: PaceHistoryMeterId,
        meter: QuotaMeter,
        now: Date
    ) -> PaceHistorySample? {
        guard !meter.isUnavailable,
              let usedPct = meter.percentUsed,
              let elapsedPct = meter.periodElapsedPercent(now: now),
              let periodStart = meter.periodStart else {
            return nil
        }
        return PaceHistorySample(
            meterId: meterId,
            usedPct: usedPct,
            elapsedPct: elapsedPct,
            timestamp: now,
            periodStart: periodStart
        )
    }

    private var discrepancyDetectorTask: Task<Void, Never>?
    private var isDetectingCursorActivity = false

    private func scheduleCursorDiscrepancyDetector(at timestamp: Date, accessToken: String) {
        discrepancyDetectorTask = Task { [weak self] in
            await self?.updateCursorDiscrepancyDetector(at: timestamp, accessToken: accessToken)
        }
    }

    /// Keeps filesystem access in the app target and matching rules in QuotAICore.
    private func updateCursorDiscrepancyDetector(at timestamp: Date, accessToken: String) async {
        guard discrepancyDetectionEnabled, !isDetectingCursorActivity,
              let periodStart = cursorModels.periodStart ?? otherModels.periodStart
        else {
            return
        }
        isDetectingCursorActivity = true
        defer { isDetectingCursorActivity = false }
        do {
            try cursorActivityStore.replacePeriodIfNeeded(periodStart: periodStart)
            var priorOffsets = cursorActivityStore.state.logByteOffsets
            // Upgrade path: turns already on disk, offsets never persisted → mark EOF
            // consumed so the first post-fix launch does not re-parse historical logs.
            if priorOffsets.isEmpty, !cursorActivityStore.state.turns.isEmpty {
                let reader = cursorLogActivityReader
                priorOffsets = await Task.detached {
                    reader.currentFileSizes()
                }.value
                try cursorActivityStore.replaceLogByteOffsets(priorOffsets)
            }
            // Rescan once for stale activity ends and for routing reasons omitted by
            // older caches, even if an earlier format backfill already ran.
            if cursorActivityStore.state.needsTurnActivityBackfill || cursorActivityStore.state.needsBillingRoutingBackfill {
                priorOffsets = [:]
            }
            let knownTurns = cursorActivityStore.state.turns
            let reader = cursorLogActivityReader
            let read = await Task.detached {
                reader.readNewTurns(priorOffsets: priorOffsets, knownTurns: knownTurns)
            }.value
            let turns = read.turns.filter { $0.timestamp >= periodStart }
            try cursorActivityStore.append(turns: turns)
            // Persist the activity before advancing cursors so an interrupted save can
            // safely replay records rather than permanently skipping them.
            try cursorActivityStore.replaceLogByteOffsets(read.offsets)
            try cursorActivityStore.markTurnEndedAtBackfilled()
            if read.isComplete {
                try cursorActivityStore.markBillingRoutingBackfilled()
            }
            let paceSamples =
                paceHistoryStore.series(for: .cursor) + paceHistoryStore.series(for: .other)
            let backfilled = CursorDiscrepancySnapshotBackfill.snapshots(
                from: paceSamples,
                periodStart: periodStart
            )
            try cursorActivityStore.append(snapshots: backfilled)
            try cursorActivityStore.append(
                snapshots: [
                    CursorMeterSnapshot(
                        timestamp: timestamp,
                        cursorModelsPercentUsed: cursorModels.percentUsed,
                        otherModelsPercentUsed: otherModels.percentUsed
                    )
                ]
            )

            var state = cursorActivityStore.state
            let candidates = CursorDiscrepancyReconciler.reconcile(
                turns: state.turns,
                snapshots: state.snapshots,
                billingChecks: state.billingChecks,
                now: timestamp
            )
            let windows = CursorUsageBilling.windows(
                events: candidates, turns: state.turns, checks: state.billingChecks,
                lastLookup: state.lastBillingLookupAt, now: timestamp
            )
            if !windows.isEmpty {
                try cursorActivityStore.recordBillingLookup(at: timestamp)
                let lookupTurns = state.turns
                for window in windows {
                    guard discrepancyDetectionEnabled,
                          (cursorModels.periodStart ?? otherModels.periodStart) == periodStart else { return }
                    do {
                        let checks = try await Task.detached {
                            let result = try await CursorUsageBillingClient.fetch(window: window, accessToken: accessToken)
                            return CursorUsageBilling.checks(
                                for: window, records: result.records, complete: result.complete,
                                turns: lookupTurns, now: timestamp
                            )
                        }.value
                        guard discrepancyDetectionEnabled,
                              (self.cursorModels.periodStart ?? self.otherModels.periodStart) == periodStart else { return }
                        try cursorActivityStore.merge(billingChecks: checks)
                    } catch {
                        // Optional billing enrichment never fails quota refresh or invents Free status.
                        break
                    }
                }
            }
            guard discrepancyDetectionEnabled,
                  (cursorModels.periodStart ?? otherModels.periodStart) == periodStart else { return }
            state = cursorActivityStore.state
            let events = CursorDiscrepancyReconciler.reconcile(
                turns: state.turns, snapshots: state.snapshots, billingChecks: state.billingChecks, now: timestamp
            )
            let known = Set(state.events.map(\.notificationSignature))
            let newEvents = events.filter { !known.contains($0.notificationSignature) }
            try cursorActivityStore.replace(events: events)
            cursorDiscrepancyEvents = cursorActivityStore.state.events

            guard discrepancyNotificationsEnabled, !newEvents.isEmpty else { return }
            let signature = newEvents.map(\.notificationSignature).sorted().joined(separator: "\n")
            guard UserDefaults.standard.string(forKey: Self.discrepancyNotificationSignatureKey) != signature else {
                return
            }
            let accepted = await NotificationAlertService.deliver(
                subject: "QuotAI: Cursor usage discrepancy",
                body: discrepancyNotificationBody(for: newEvents[newEvents.count - 1])
            )
            if accepted {
                UserDefaults.standard.set(signature, forKey: Self.discrepancyNotificationSignatureKey)
            }
        } catch {
            // A local detector-cache failure must never interrupt quota refresh.
        }
    }

    private func discrepancyNotificationBody(for event: CursorDiscrepancyEvent) -> String {
        let meter = event.meter == .cursorModels ? "Cursor Models" : "Other Models"
        switch event.kind {
        case .unbilledActivity:
            let models = event.displayModelLabel
            let modelsSuffix = models == "—" ? "" : " Models: \(models)."
            return "Observed activity did not raise \(meter) within five minutes." + modelsSuffix
        case .unattributedQuotaChange:
            return "\(meter) increased without a matching local activity record."
        }
    }

    /// One re-read of the Cursor session, then a real fetch. Calling `refresh` here
    /// no-ops because this attempt is already in flight.
    private func handleAuthFailure(scope: RefreshScope) async {
        if !didAttemptAuthFailureReimport {
            didAttemptAuthFailureReimport = true
            if let imported = try? CursorVscdbImporter.importCredentials() {
                try? KeychainStore.save(imported)
                do {
                    try await fetchAndApply(scope: scope, forceReimport: false)
                    return
                } catch CursorConnectClient.ClientError.unauthorized,
                        CursorConnectClient.ClientError.shouldLogout,
                        CursorConnectClient.ClientError.refreshFailed {
                    // Fall through to the re-auth message.
                } catch {
                    refreshError = Self.refreshFailureMessage(error)
                    return
                }
            }
        }
        authError = "Auth error — re-auth or paste token"
    }

    private static func refreshFailureMessage(_ error: Error) -> String {
        if let url = error as? URLError {
            switch url.code {
            case .timedOut: return "Refresh failed — timed out"
            case .notConnectedToInternet, .networkConnectionLost: return "Refresh failed — offline"
            default: break
            }
        }
        if case CursorConnectClient.ClientError.httpStatus(let code) = error {
            return "Refresh failed — HTTP \(code)"
        }
        return "Refresh failed"
    }
}
