import AppKit
import Combine
import Foundation
import QuotAICore
import SwiftUI

@MainActor
final class QuotaStore: ObservableObject {
    @Published var cursorModels = QuotaMeter(name: "Cursor Models")
    @Published var otherModels = QuotaMeter(name: "Other Models", isUnavailable: true)
    @Published var grokBot = QuotaMeter(name: "Grok Bot", isUnavailable: true)
    @Published var authError: String?
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?

    private var didAttemptAuthFailureReimport = false
    private var pollTimer: Timer?
    private var pollActivity: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?

    static let pollIntervalChoices = [5, 10, 15, 30, 60]
    private static let pollIntervalKey = "pollIntervalMinutes"

    /// User-set auto-refresh interval; unofficial endpoints, so 1 h is the ceiling.
    @Published var pollIntervalMinutes: Int {
        didSet {
            guard pollIntervalMinutes != oldValue else { return }
            UserDefaults.standard.set(pollIntervalMinutes, forKey: Self.pollIntervalKey)
            startPolling(refreshNow: false)
        }
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.pollIntervalKey)
        pollIntervalMinutes = Self.pollIntervalChoices.contains(stored) ? stored : 10
        startPolling(refreshNow: true)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    deinit {
        pollTimer?.invalidate()
        if let pollActivity { ProcessInfo.processInfo.endActivity(pollActivity) }
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
    }

    /// Menu-bar apps nap hard; RunLoop timer + activity keep the cadence honest.
    private func startPolling(refreshNow: Bool) {
        pollTimer?.invalidate()
        if let pollActivity {
            ProcessInfo.processInfo.endActivity(pollActivity)
            self.pollActivity = nil
        }

        let interval = TimeInterval(max(1, pollIntervalMinutes) * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        timer.tolerance = min(30, interval * 0.1)
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer

        pollActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "QuotAI quota polling"
        )

        if refreshNow {
            Task { await self.refresh() }
        }
    }

    /// Pull now if the last successful fetch is older than the poll interval (or never).
    func refreshIfStale() async {
        let maxAge = TimeInterval(pollIntervalMinutes * 60)
        if let lastRefreshed, Date().timeIntervalSince(lastRefreshed) < maxAge {
            return
        }
        await refresh()
    }

    func refresh(forceReimport: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let credentials = try await resolveCredentials(forceReimport: forceReimport)
            let result = try await CursorConnectClient.fetchMeters(credentials: credentials)
            try KeychainStore.save(result.credentials)
            cursorModels = result.cursorModels
            otherModels = result.otherModels
            grokBot = result.grokBot
            authError = nil
            didAttemptAuthFailureReimport = false
            lastRefreshed = Date()
            let includeOther = UserDefaults.standard.bool(forKey: "showOtherModels")
            await PaceAlertOrchestrator.handleSuccessfulRefresh(
                cursor: result.cursorModels,
                other: includeOther ? result.otherModels : nil,
                grok: result.grokBot
            )
        } catch CursorConnectClient.ClientError.unauthorized,
                CursorConnectClient.ClientError.shouldLogout,
                CursorConnectClient.ClientError.refreshFailed {
            await handleAuthFailure()
        } catch {
            if authError == nil {
                authError = "Refresh failed"
            }
        }
    }

    func reauthFromCursor() async {
        didAttemptAuthFailureReimport = false
        await refresh(forceReimport: true)
    }

    func pasteAccessToken(_ accessToken: String, refreshToken: String?) {
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let refreshTrimmed = (refreshToken ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let creds = QuotAIKeychain.Credentials(
            accessToken: trimmed,
            refreshToken: refreshTrimmed.isEmpty ? trimmed : refreshTrimmed
        )
        do {
            try KeychainStore.save(creds)
            authError = nil
            Task { await self.refresh() }
        } catch {
            authError = "Could not save token"
        }
    }

    private func resolveCredentials(forceReimport: Bool) async throws -> QuotAIKeychain.Credentials {
        if !forceReimport, let existing = try KeychainStore.load() {
            return existing
        }
        if let imported = try CursorVscdbImporter.importCredentials() {
            try KeychainStore.save(imported)
            return imported
        }
        if let existing = try KeychainStore.load() {
            return existing
        }
        throw CursorConnectClient.ClientError.unauthorized
    }

    private func handleAuthFailure() async {
        if !didAttemptAuthFailureReimport {
            didAttemptAuthFailureReimport = true
            if let imported = try? CursorVscdbImporter.importCredentials() {
                try? KeychainStore.save(imported)
                await refresh()
                return
            }
        }
        authError = "Auth error — re-auth or paste token"
    }
}
