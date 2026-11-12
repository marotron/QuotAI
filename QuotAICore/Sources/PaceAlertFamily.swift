import Foundation

/// Corridor alert profile family. Models + Other share Cursor; Grok has its own dials.
public enum PaceAlertFamily: String, Equatable, Hashable, Sendable {
    case cursor
    case grok

    /// Map orchestrator / history meter ids. Unknown ids share Cursor.
    public static func resolve(meterId: String) -> PaceAlertFamily {
        switch meterId {
        case "grok":
            return .grok
        default:
            return .cursor
        }
    }

    /// Map live `QuotaMeter.name` values used by the menu / Settings.
    public static func resolve(meterName: String) -> PaceAlertFamily {
        meterName == "Grok Bot" ? .grok : .cursor
    }

    public static func thresholds(
        forMeterId meterId: String,
        cursor: PaceAlertThresholds,
        grok: PaceAlertThresholds
    ) -> PaceAlertThresholds {
        switch resolve(meterId: meterId) {
        case .cursor:
            return cursor
        case .grok:
            return grok
        }
    }
}
