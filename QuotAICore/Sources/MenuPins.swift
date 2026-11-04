import Foundation

/// Rows a user can pin into the menu bar dropdown. Raw value is the `@AppStorage` pin key.
public enum MenuPin: String, CaseIterable, Hashable, Sendable {
    case refreshAll = "pinRefreshAll"
    case refreshCursor = "pinRefreshCursor"
    case refreshGrok = "pinRefreshGrok"
    case refreshInterval = "pinRefreshInterval"
    case openCursorSpending = "pinOpenCursorSpending"
    case iconLook = "pinIconLook"
    case colorMode = "pinColorMode"
    case showOtherModels = "pinShowOtherModels"
    case showAvatars = "pinShowAvatars"
    case showUsedPercent = "pinShowPercent"
    case showElapsedPercent = "pinShowElapsedPercent"
    case showRemaining = "pinShowRemaining"
    case alternateElapsedRemaining = "pinAlternateElapsedRemaining"
    case ringCenterContent = "pinRingCenterContent"
    case blink = "pinBlink"

    public var group: MenuPinGroup {
        switch self {
        case .refreshAll, .refreshCursor, .refreshGrok, .refreshInterval, .openCursorSpending:
            return .actions
        case .iconLook, .colorMode, .showOtherModels, .ringCenterContent:
            return .display
        case .showAvatars, .showUsedPercent, .showElapsedPercent, .showRemaining, .alternateElapsedRemaining:
            return .besideMeter
        case .blink:
            return .blink
        }
    }
}

/// Dropdown sections, top to bottom. Each visible section starts after a rule.
public enum MenuPinGroup: CaseIterable, Hashable, Sendable {
    case actions
    case display
    case besideMeter
    case blink
}

/// One visible dropdown section: its group and the pins that are on, in enum order.
public struct MenuPinSection: Equatable, Sendable {
    public let group: MenuPinGroup
    public let pins: [MenuPin]

    public init(group: MenuPinGroup, pins: [MenuPin]) {
        self.group = group
        self.pins = pins
    }
}

/// Dropdown density: `compact` uses smaller text and two columns, `normal` uses regular text and one column.
public enum MenuPinDensity: String, CaseIterable, Hashable, Sendable {
    case compact
    case normal

    public var columnCount: Int {
        switch self {
        case .compact: return 2
        case .normal: return 1
        }
    }
}

public enum MenuPinLayout {
    /// Sections with at least one pinned row, in `MenuPinGroup` order.
    public static func sections(isOn: (MenuPin) -> Bool) -> [MenuPinSection] {
        MenuPinGroup.allCases.compactMap { group in
            let pins = MenuPin.allCases.filter { $0.group == group && isOn($0) }
            return pins.isEmpty ? nil : MenuPinSection(group: group, pins: pins)
        }
    }
}
