import AppKit
import SwiftUI
import QuotAICore

struct CodexAccountSettings: View {
    @ObservedObject var store: CodexQuotaStore

    var body: some View {
        Section {
            Toggle("Enable Codex quota", isOn: $store.enabled)
            if store.enabled {
                if let email = store.email { Text(email).foregroundStyle(.secondary).textSelection(.enabled) }
                if let error = store.error { Text(error).foregroundStyle(.orange) }
                HStack {
                    if store.isSigningIn {
                        ProgressView().controlSize(.small)
                        Button("Cancel sign-in") { store.cancelSignIn() }
                    } else {
                        Button(store.requiresSignIn ? "Sign in to Codex…" : "Sign in to another account…") { store.signIn() }
                            .disabled(store.isRefreshing)
                    }
                    if !store.requiresSignIn {
                        Button("Disconnect") { store.disconnect() }
                            .disabled(store.isRefreshing)
                    }
                }
                Toggle("Show Codex windows in menu bar", isOn: $store.showInMenuBar)
                Toggle("Track Codex 5h→7d ratio (experimental)", isOn: $store.trackFiveHourWeeklyRatio)
                Text("Records closed 5-hour periods forever. The list is under Advanced → Codex 5h→7d on the pace chart. Disconnect or turning the toggle off stops new records; history stays.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Sign in in your browser. Credentials stay in QuotAI’s Keychain item; your existing Codex login is unchanged.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        } header: { Text("Codex") }
    }
}

struct CodexPanelSection: View {
    @ObservedObject var store: CodexQuotaStore

    var body: some View {
        if store.enabled {
            VStack(alignment: .leading, spacing: 5) {
                if store.requiresSignIn || store.isSigningIn {
                    HStack {
                        Text(store.isSigningIn ? "Complete sign-in in your browser" : "Sign in to see Codex quota")
                        Spacer()
                        Button(store.isSigningIn ? "Cancel" : "Sign in…") {
                            if store.isSigningIn { store.cancelSignIn() } else { store.signIn() }
                        }
                    }.font(.system(size: 11))
                }
                if !store.requiresSignIn, !store.isRefreshing, store.windows.isEmpty {
                    Text("No quota windows available").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                // Refresh failures surface once in the panel notice stack; keep sign-in errors here.
                if store.requiresSignIn, let error = store.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 19)
        }
    }

}
