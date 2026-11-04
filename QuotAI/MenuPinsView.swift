import AppKit
import SwiftUI
import QuotAICore

/// Pinned rows in the menu bar dropdown. Pin flags come from Settings → Menu pins;
/// each row reads and writes the real setting or action it mirrors.
struct MenuPinsView: View {
    @ObservedObject var store: QuotaStore

    @Environment(\.menuRowMetrics) private var metrics

    // Pin flags: same keys and defaults as Settings → Menu pins.
    @AppStorage("pinRefreshAll") private var pinRefreshAll = true
    @AppStorage("pinRefreshCursor") private var pinRefreshCursor = false
    @AppStorage("pinRefreshGrok") private var pinRefreshGrok = false
    @AppStorage("pinRefreshInterval") private var pinRefreshInterval = true
    @AppStorage("pinOpenCursorSpending") private var pinOpenCursorSpending = true
    @AppStorage("pinIconLook") private var pinIconLook = false
    @AppStorage("pinColorMode") private var pinColorMode = false
    @AppStorage("pinShowOtherModels") private var pinShowOtherModels = false
    @AppStorage("pinShowAvatars") private var pinShowAvatars = false
    @AppStorage("pinShowPercent") private var pinShowPercent = false
    @AppStorage("pinShowElapsedPercent") private var pinShowElapsedPercent = false
    @AppStorage("pinShowRemaining") private var pinShowRemaining = false
    @AppStorage("pinAlternateElapsedRemaining") private var pinAlternateElapsedRemaining = false
    @AppStorage("pinRingCenterContent") private var pinRingCenterContent = false
    @AppStorage("pinBlink") private var pinBlink = false

    // Real settings the rows write to (same keys as Settings and QuotAIApp).
    @AppStorage("iconLook") private var iconLook: IconLook = .bars
    @AppStorage("iconColorMode") private var iconColorMode: IconColorMode = .monochrome
    @AppStorage("showOtherModels") private var showOtherModels = false
    @AppStorage("showAvatars") private var showAvatars = true
    @AppStorage("showPercent") private var showUsedPercent = true
    @AppStorage("showElapsedPercent") private var showElapsedPercent = true
    @AppStorage("showRemaining") private var showRemaining = false
    @AppStorage("alternateElapsedRemaining") private var alternateElapsedRemaining = false
    @AppStorage("ringCenterContent") private var ringCenterContent: RingCenterContent = .remaining
    @AppStorage("blinkSignificantPace") private var blinkSignificantPace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(MenuPinLayout.sections(isOn: isOn), id: \.group) { section in
                sectionContent(section)
            }
        }
    }

    // MARK: - Layout

    private func sectionContent(_ section: MenuPinSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelRule(title: section.group.headerTitle)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 0, alignment: .leading),
                    count: metrics.columns
                ),
                alignment: .leading,
                spacing: 0
            ) {
                ForEach(Array(section.pins.enumerated()), id: \.element) { index, pin in
                    pinCell(pin)
                        .padding(columnGutter(for: index))
                }
            }
            .padding(.horizontal, 5)
            .overlay(alignment: .center) {
                if metrics.columns > 1 {
                    PanelColumnDivider()
                }
            }
        }
    }

    /// Space between the two columns, split evenly on each side of the vertical divider.
    private static let columnGutter: CGFloat = 12

    /// Insets each cell from the divider so row highlights stop short of the line.
    private func columnGutter(for index: Int) -> EdgeInsets {
        guard metrics.columns > 1 else { return EdgeInsets() }
        let half = Self.columnGutter / 2
        let column = index % metrics.columns
        return EdgeInsets(
            top: 0,
            leading: column > 0 ? half : 0,
            bottom: 0,
            trailing: column < metrics.columns - 1 ? half : 0
        )
    }

    private func isOn(_ pin: MenuPin) -> Bool {
        switch pin {
        case .refreshAll: return pinRefreshAll
        case .refreshCursor: return pinRefreshCursor
        case .refreshGrok: return pinRefreshGrok
        case .refreshInterval: return pinRefreshInterval
        case .openCursorSpending: return pinOpenCursorSpending
        case .iconLook: return pinIconLook
        case .colorMode: return pinColorMode
        case .showOtherModels: return pinShowOtherModels
        case .showAvatars: return pinShowAvatars
        case .showUsedPercent: return pinShowPercent
        case .showElapsedPercent: return pinShowElapsedPercent
        case .showRemaining: return pinShowRemaining
        case .alternateElapsedRemaining: return pinAlternateElapsedRemaining
        case .ringCenterContent: return pinRingCenterContent
        case .blink: return pinBlink
        }
    }

    // MARK: - Cells

    @ViewBuilder
    private func pinCell(_ pin: MenuPin) -> some View {
        switch pin {
        case .refreshAll:
            PanelActionRow(title: "Refresh all") {
                Task { await store.refresh(.all) }
            }
            .disabled(store.isRefreshing)
        case .refreshCursor:
            PanelActionRow(title: "Refresh Cursor") {
                Task { await store.refresh(.cursor) }
            }
            .disabled(store.isRefreshing)
        case .refreshGrok:
            PanelActionRow(title: "Refresh Grok Bot") {
                Task { await store.refresh(.grok) }
            }
            .disabled(store.isRefreshing)
        case .openCursorSpending:
            PanelActionRow(title: "Open Cursor Spending") {
                #if !PANEL_PREVIEW
                    NSWorkspace.shared.open(MenuPresenter.spendingURL)
                #endif
            }
        case .refreshInterval:
            pickerCell("Refresh interval", selection: store.refreshEveryBinding(), options: refreshOptions)
        case .iconLook:
            pickerCell(
                "Style",
                selection: $iconLook,
                options: IconLook.allCases.map { MenuPinOption(value: $0, label: $0.pickerTitle) }
            )
        case .colorMode:
            pickerCell(
                "Color mode",
                selection: $iconColorMode,
                options: IconColorMode.allCases.map { MenuPinOption(value: $0, label: $0.pickerTitle) }
            )
        case .ringCenterContent:
            pickerCell(
                "Ring center",
                selection: $ringCenterContent,
                options: RingCenterContent.allCases.map { MenuPinOption(value: $0, label: $0.pickerTitle) }
            )
        case .showOtherModels:
            switchCell("Show Other Models", isOn: $showOtherModels)
        case .showAvatars:
            switchCell("Show icons", isOn: $showAvatars)
        case .showUsedPercent:
            switchCell("Show used %", isOn: $showUsedPercent)
        case .showElapsedPercent:
            switchCell("Show elapsed %", isOn: $showElapsedPercent)
        case .showRemaining:
            switchCell("Show time to reset", isOn: $showRemaining)
        case .alternateElapsedRemaining:
            switchCell("Alternate % / reset", isOn: $alternateElapsedRemaining)
        case .blink:
            switchCell("Blink on significant pace", isOn: $blinkSignificantPace)
        }
    }

    private var refreshOptions: [MenuPinOption<Int>] {
        QuotaStore.pollIntervalChoices.map { MenuPinOption(value: $0, label: RefreshChoiceTitle.title(minutes: $0)) }
            + [MenuPinOption(value: QuotaStore.dynamicRefreshTag, label: "Dynamic")]
    }

    /// Label left, current value + chevron right. Shared by every picker so the control edge lines up in its column.
    private func pickerCell<Selection: Hashable>(
        _ title: String,
        selection: Binding<Selection>,
        options: [MenuPinOption<Selection>]
    ) -> some View {
        let current = options.first { $0.value == selection.wrappedValue }?.label ?? ""
        return HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            Menu {
                ForEach(options) { option in
                    Button {
                        selection.wrappedValue = option.value
                    } label: {
                        if option.value == selection.wrappedValue {
                            Image(systemName: "checkmark")
                        }
                        Text(option.label)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(current)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: metrics.fontSize - 3, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .frame(maxWidth: metrics.pickerWidth, alignment: .trailing)
        }
        .font(.system(size: metrics.fontSize))
        .padding(.horizontal, metrics.inset)
        .frame(minHeight: metrics.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Label left, switch pinned to the right edge of its column so switches line up vertically.
    private func switchCell(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .lineLimit(1)
                .fixedSize()
                .contentShape(Rectangle())
                .onTapGesture { isOn.wrappedValue.toggle() }
            Spacer(minLength: 0)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(metrics.switchSize)
        }
        .font(.system(size: metrics.fontSize))
        .padding(.horizontal, metrics.inset)
        .frame(minHeight: metrics.rowHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Text size, row height, and column layout for the dropdown. Set once on the panel root.
struct MenuRowMetrics: Equatable {
    let density: MenuPinDensity

    var columns: Int { density.columnCount }
    var fontSize: CGFloat { density == .compact ? 11 : 13 }
    var headerSize: CGFloat { density == .compact ? 10 : 11 }
    var rowHeight: CGFloat { density == .compact ? 22 : 26 }
    /// Horizontal padding inside each row, so labels line up with the panel's rules and meters.
    var inset: CGFloat { density == .compact ? 9 : 14 }
    var pickerWidth: CGFloat { density == .compact ? 120 : 180 }
    var switchSize: ControlSize { density == .compact ? .mini : .small }
}

private struct MenuRowMetricsKey: EnvironmentKey {
    static let defaultValue = MenuRowMetrics(density: .compact)
}

extension EnvironmentValues {
    var menuRowMetrics: MenuRowMetrics {
        get { self[MenuRowMetricsKey.self] }
        set { self[MenuRowMetricsKey.self] = newValue }
    }
}

/// One choice in a dropdown picker row.
struct MenuPinOption<Value: Hashable>: Identifiable {
    let value: Value
    let label: String

    var id: Value { value }
}

/// Vertical hairline between the two columns in compact layout. Callers overlay it on a two-column row.
struct PanelColumnDivider: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Rectangle()
            .fill(PanelRule.dividerColor(colorScheme))
            .frame(width: 1)
            .padding(.vertical, 4)
    }
}

/// Hairline between panel sections. With a `title`, the label sits in the line
/// (`—— TEMPERATURE ——`), the section header style used by macOS Sensors.
struct PanelRule: View {
    var title: String? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.menuRowMetrics) private var metrics

    var body: some View {
        HStack(spacing: 8) {
            line
            if let title {
                Text(title.uppercased())
                    .font(.system(size: metrics.headerSize, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .fixedSize()
                line
            }
        }
        .padding(.vertical, title == nil ? 5 : 6)
        .padding(.horizontal, 14)
    }

    private var line: some View {
        Rectangle()
            .fill(Self.dividerColor(colorScheme))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    static func dividerColor(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0x3a / 255, green: 0x3a / 255, blue: 0x3c / 255)
            : Color(red: 0xd2 / 255, green: 0xd2 / 255, blue: 0xd7 / 255)
    }
}
