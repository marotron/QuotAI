import SwiftUI
import QuotAICore

/// Design-preview host for `MenuBarWindowPanel`.
///
/// Compiles the real panel sources (shared with the `QuotAI` target) against a seeded
/// `QuotaStore` — no timers, no network, no keychain. Panel actions stay look-only via
/// `#if PANEL_PREVIEW` guards; the appearance picker flips the panel between light and
/// dark so both palettes can be checked side by side.
@main
struct QuotAIPanelPreviewApp: App {
    @StateObject private var store = QuotaStore(
        previewHistoryFileURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("quotai-panel-preview-history.json")
    )

    var body: some Scene {
        WindowGroup {
            PanelPreviewRoot(store: store)
        }
        .windowResizability(.contentSize)
    }
}

private enum PreviewAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct PanelPreviewRoot: View {
    @ObservedObject var store: QuotaStore
    @State private var appearance: PreviewAppearance = .system

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Picker("Appearance", selection: $appearance) {
                    ForEach(PreviewAppearance.allCases) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(.bar)

            MenuBarWindowPanel(
                store: store,
                showOtherModels: true,
                corridorAlertsEnabled: true,
                cursorThresholds: .default,
                grokThresholds: .grokDefault
            )
            .preferredColorScheme(appearance.scheme)
        }
        .frame(width: 470)
    }
}

// Xcode canvas previews — near-instant visual iteration without building/launching.
// Each canvas runs the seeded store, so no network and no side effects.
#Preview("Dropdown panel") {
    PanelPreviewRoot(
        store: QuotaStore(
            previewHistoryFileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("quotai-panel-preview-history.json")
        )
    )
}
