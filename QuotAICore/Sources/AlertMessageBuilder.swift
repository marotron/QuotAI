import Foundation

public struct PaceAlertMeterDetail: Equatable, Sendable {
    public var name: String
    public var kind: PaceAlertKind
    public var percentUsed: Double
    public var elapsedPercent: Double

    public init(name: String, kind: PaceAlertKind, percentUsed: Double, elapsedPercent: Double) {
        self.name = name
        self.kind = kind
        self.percentUsed = percentUsed
        self.elapsedPercent = elapsedPercent
    }
}

/// Pure subject/body for notifications and email.
public enum AlertMessageBuilder {
    public static func subject(alerts: [PaceAlertMeterAlert]) -> String {
        let parts = alerts.map { "\($0.name) \(kindWord($0.kind))" }
        return "QuotAI: " + parts.joined(separator: " · ")
    }

    public static func body(alerts: [PaceAlertMeterDetail]) -> String {
        alerts.map { detail in
            let used = formatPercent(detail.percentUsed)
            let elapsed = formatPercent(detail.elapsedPercent)
            return "\(detail.name): \(kindWord(detail.kind)) — \(used) used / \(elapsed) elapsed"
        }
        .joined(separator: "\n")
    }

    private static func kindWord(_ kind: PaceAlertKind) -> String {
        switch kind {
        case .quiet: return "quiet"
        case .under: return "under"
        case .over: return "over"
        case .exhausted: return "exhausted"
        }
    }

    private static func formatPercent(_ value: Double) -> String {
        if value == floor(value) {
            return "\(Int(value))%"
        }
        return String(format: "%.1f%%", value)
    }
}
