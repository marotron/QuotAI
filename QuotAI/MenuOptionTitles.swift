import QuotAICore

/// Picker labels shared by Settings → Display / Account and the menu bar dropdown pins.
extension IconLook {
    var pickerTitle: String {
        switch self {
        case .bars: return "Bars"
        case .ringsPerQuota: return "Rings · one per meter"
        case .ringsPaired: return "Rings · nested Cursor"
        case .ringsPace: return "Rings · by pace"
        }
    }
}

extension IconColorMode {
    var pickerTitle: String {
        switch self {
        case .monochrome: return "Monochrome"
        case .byLevel: return "By pace"
        }
    }
}

extension RingCenterContent {
    var pickerTitle: String {
        switch self {
        case .none: return "Nothing"
        case .remaining: return "Time to reset"
        case .icon: return "Icon"
        }
    }
}

extension MenuPinDensity {
    var pickerTitle: String {
        switch self {
        case .compact: return "Compact"
        case .normal: return "Normal"
        }
    }
}

/// Grey section headers in the dropdown (same wording family as Settings → Menu pins).
extension MenuPinGroup {
    var headerTitle: String {
        switch self {
        case .actions: return "Actions"
        case .display: return "Menu bar · Display"
        case .besideMeter: return "Menu bar · Beside meter"
        case .blink: return "Alerts"
        }
    }
}

enum RefreshChoiceTitle {
    static func title(minutes: Int) -> String {
        minutes == 60 ? "every 1 hour" : "every \(minutes) min"
    }
}
