import Combine
import Foundation
import QuotAICore
import Security

/// A separate Keychain item: never imports or modifies Cursor/CLI credentials.
private enum CodexCredentialStore {
    static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "dev.marotron.QuotAI",
        kSecAttrAccount as String: "codex-oauth",
    ]

    static func load() throws -> CodexCredentials? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw failure() }
        return try JSONDecoder().decode(CodexCredentials.self, from: data)
    }

    static func save(_ credentials: CodexCredentials) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: try JSONEncoder().encode(credentials),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            guard SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil) == errSecSuccess else { throw failure() }
        } else if status != errSecSuccess { throw failure() }
    }

    static func clear() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure() }
    }

    static func failure() -> CodexServiceError { .message("Codex credentials could not be accessed in Keychain. Check Keychain access and try again.") }
}

@MainActor
final class CodexQuotaStore: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            guard !preview else { return }
            defaults.set(enabled, forKey: "codexEnabled")
            if enabled { loadCredentials() }
            else { generation += 1; loginTask?.cancel(); isSigningIn = false }
            changed()
        }
    }
    @Published var showInMenuBar: Bool {
        didSet { if !preview { defaults.set(showInMenuBar, forKey: "codexShowInMenuBar") } }
    }
    @Published private(set) var windows: [CodexQuotaWindow] = []
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var error: String?
    @Published private(set) var email: String?
    @Published private(set) var requiresSignIn = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSigningIn = false
    @Published private(set) var ordinaryUsageAllowed: Bool?
    @Published private(set) var rules: [String: CodexRefreshRule] = [:]

    var onScheduleChange: (() -> Void)?
    private let defaults: UserDefaults
    private let preview: Bool
    private let client = CodexNativeClient()
    private var credentials: CodexCredentials?
    private var refreshState = CodexRefreshState()
    private var retryAfter: Date?
    private var lastAttempt: Date?
    private var generation = 0
    private var loginTask: Task<Void, Never>?

    init(preview: Bool = false, defaults: UserDefaults = .standard) {
        self.preview = preview
        self.defaults = defaults
        enabled = !preview && defaults.bool(forKey: "codexEnabled")
        showInMenuBar = !preview && defaults.bool(forKey: "codexShowInMenuBar")
        if !preview {
            if let data = defaults.data(forKey: "codexRefreshRules"),
               let decoded = try? JSONDecoder().decode([String: CodexRefreshRule].self, from: data) {
                rules = decoded.mapValues(\.normalized)
            }
            if let data = defaults.data(forKey: "codexRefreshState"),
               let state = try? JSONDecoder().decode(CodexRefreshState.self, from: data) { refreshState = state }
            if enabled { loadCredentials() }
        }
    }

    #if PANEL_PREVIEW
    func seedPanelPreview(now: Date) {
        enabled = true
        requiresSignIn = false
        lastRefreshed = now.addingTimeInterval(-60)
        let data = """
        {"rate_limit":{"primary_window":{"used_percent":23,"limit_window_seconds":18000,"reset_at":\(now.addingTimeInterval(13560).timeIntervalSince1970)},"secondary_window":{"used_percent":37,"limit_window_seconds":604800,"reset_at":\(now.addingTimeInterval(511200).timeIntervalSince1970)}}}
        """.data(using: .utf8)!
        windows = (try? CodexQuotaSnapshot.parse(data, expectedAccount: "preview").windows) ?? []
    }
    #endif

    private func loadCredentials() {
        do {
            credentials = try CodexCredentialStore.load()
            email = credentials?.email
            requiresSignIn = credentials == nil
            error = nil
        } catch {
            requiresSignIn = true
            self.error = CodexCredentialStore.failure().localizedDescription
        }
    }

    func signIn() {
        guard enabled, !preview, !isSigningIn, !isRefreshing else { return }
        generation += 1
        let attempt = generation
        isSigningIn = true
        error = nil
        loginTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.generation == attempt { self.isSigningIn = false; self.loginTask = nil }
                self.changed()
            }
            do {
                let newCredentials = try await self.client.signIn()
                try Task.checkCancellation()
                guard self.enabled, self.generation == attempt else { return }
                try CodexCredentialStore.save(newCredentials)
                // A new account starts with no old readings, freshness or trigger state.
                self.credentials = newCredentials
                self.email = newCredentials.email
                self.windows = []
                self.lastRefreshed = nil
                self.ordinaryUsageAllowed = nil
                self.refreshState = CodexRefreshState()
                self.persistRefreshState()
                self.requiresSignIn = false
                self.retryAfter = nil
                self.lastAttempt = nil
                self.isSigningIn = false
                await self.refresh()
            } catch is CancellationError { /* An explicit cancel is quiet. */ }
            catch {
                guard self.generation == attempt else { return }
                self.error = self.message(for: error)
            }
        }
    }

    func cancelSignIn() {
        generation += 1
        loginTask?.cancel()
        loginTask = nil
        isSigningIn = false
        changed()
    }

    func disconnect() {
        cancelSignIn()
        do { try CodexCredentialStore.clear() }
        catch { self.error = message(for: error); return }
        credentials = nil
        email = nil
        windows = []
        lastRefreshed = nil
        ordinaryUsageAllowed = nil
        requiresSignIn = true
        error = nil
        refreshState = CodexRefreshState()
        persistRefreshState()
        retryAfter = nil
        lastAttempt = nil
        changed()
    }

    func refresh(automatic: Bool = false) async {
        guard !preview, enabled, !requiresSignIn, !isSigningIn, !isRefreshing,
              var active = credentials else { return }
        if automatic, let retryAfter, retryAfter > Date() { return }
        let attempt = generation
        isRefreshing = true
        lastAttempt = Date()
        defer { isRefreshing = false; changed() }
        do {
            var rotated = false
            if active.expiresAt <= Date().addingTimeInterval(60) {
                active = try await client.refresh(active)
                guard enabled, generation == attempt else { return }
                credentials = active
                try CodexCredentialStore.save(active)
                rotated = true
            }
            let snapshot: CodexQuotaSnapshot
            do { snapshot = try await client.read(active) }
            catch CodexServiceError.http(_, 401) where !rotated {
                active = try await client.refresh(active)
                guard enabled, generation == attempt else { return }
                credentials = active
                try CodexCredentialStore.save(active)
                snapshot = try await client.read(active)
            }
            guard enabled, generation == attempt else { return }
            // Retry any failed Keychain write before treating a refreshed account as healthy.
            try CodexCredentialStore.save(active)
            windows = snapshot.windows
            ordinaryUsageAllowed = snapshot.ordinaryUsageAllowed
            lastRefreshed = Date()
            error = nil
            retryAfter = nil
            refreshState.update(windows: windows, rules: rules, fetchedAt: lastRefreshed, now: Date())
            persistRefreshState()
        } catch {
            guard enabled, generation == attempt else { return }
            self.error = message(for: error)
            retryAfter = Date().addingTimeInterval(300)
            if case CodexServiceError.http(_, let status) = error, [400, 401, 403].contains(status) {
                requiresSignIn = true
                self.error = "Sign in to Codex again. Previous quota readings may be stale."
            }
        }
    }

    func setRule(_ value: CodexRefreshRule, for id: String) {
        rules[id] = value.normalized
        refreshState.activeEnds.removeValue(forKey: id)
        refreshState.update(windows: windows, rules: rules, fetchedAt: lastRefreshed, now: Date())
        if !preview { defaults.set(try? JSONEncoder().encode(rules), forKey: "codexRefreshRules") }
        persistRefreshState()
        changed()
    }

    func interval(normal: TimeInterval, now: Date) -> TimeInterval {
        refreshState.interval(normal: normal, rules: rules, now: now)
    }

    func nextFire(normal: TimeInterval, now: Date) -> Date {
        guard enabled, !requiresSignIn, !isSigningIn else { return .distantFuture }
        if isRefreshing { return now.addingTimeInterval(30) }
        let last = [lastAttempt, lastRefreshed].compactMap { $0 }.max()
        let due = last.map { $0.addingTimeInterval(interval(normal: normal, now: now)) } ?? now
        return max(now, due, retryAfter ?? now)
    }

    func isStale(normal: TimeInterval, now: Date) -> Bool {
        guard enabled, !requiresSignIn else { return false }
        return lastRefreshed.map { now.timeIntervalSince($0) >= interval(normal: normal, now: now) } ?? true
    }

    private func persistRefreshState() {
        if !preview { defaults.set(try? JSONEncoder().encode(refreshState), forKey: "codexRefreshState") }
    }

    private func changed() { onScheduleChange?() }

    private func message(for error: Error) -> String {
        if let error = error as? CodexServiceError { return error.localizedDescription }
        if error is CodexQuotaSnapshot.ParseError { return "Codex returned inconsistent account or quota data. Previous readings were kept." }
        return "Codex could not be refreshed. Previous readings were kept; try again or sign in again."
    }
}
