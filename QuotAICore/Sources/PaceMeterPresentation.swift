import Foundation

/// Pure meter-row presentation for the window panel (neutral pace + corridor alert slot).
public enum PaceMeterPresentation {
    /// Pace cell copy: `N%` only, or exhausted / n/a — never under/over/on-pace words.
    public static func pacePercentText(ratio: Double?, exhausted: Bool) -> String {
        if exhausted { return "—" }
        guard let ratio else { return "—" }
        return "\(Int((ratio * 100).rounded()))%"
    }

    /// SF Symbol for the alert column (quiet = greyed checkmark).
    public static func alertSymbolName(kind: PaceAlertKind) -> String {
        switch kind {
        case .quiet: return "checkmark.circle"
        case .under: return "arrow.down.circle"
        case .over: return "arrow.up.circle"
        case .exhausted: return "xmark.circle"
        }
    }

    /// Corridor alert tint for the alert icon. Quiet → `.neutral` (greyed in UI).
    public static func alertTint(kind: PaceAlertKind) -> SymbolTint {
        switch kind {
        case .quiet: return .neutral
        case .under: return .under
        case .over: return .warning
        case .exhausted: return .critical
        }
    }
}

/// Fixed series colors for pace history trajectories / avatars / tip swatches.
/// Reserved corridor palette (blue/green/orange/red/yellow) is intentionally unused.
public enum PaceHistorySeriesColor: String, CaseIterable, Sendable {
    case models
    case other
    case grok

    public var hex: String {
        switch self {
        case .models: return "#8b5cf6"
        case .other: return "#d946ef"
        case .grok: return "#c084fc"
        }
    }

    public var endLabel: String {
        switch self {
        case .models: return "Cursor"
        case .other: return "Other"
        case .grok: return "Grok"
        }
    }
}
