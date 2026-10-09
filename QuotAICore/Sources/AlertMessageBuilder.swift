import Foundation

public struct PaceAlertMeterDetail: Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: PaceAlertKind
    public var percentUsed: Double
    public var elapsedPercent: Double

    public init(
        id: String,
        name: String,
        kind: PaceAlertKind,
        percentUsed: Double,
        elapsedPercent: Double
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.percentUsed = percentUsed
        self.elapsedPercent = elapsedPercent
    }
}

/// Pure subject/body for notifications and email.
public enum AlertMessageBuilder {
    public static func subject(alerts: [PaceAlertMeterAlert]) -> String {
        guard !alerts.isEmpty else { return "Pace alert" }
        let kinds = Set(alerts.map(\.kind))
        if kinds.count == 1, let kind = kinds.first {
            let names = alerts.map { shortLabel(id: $0.id, name: $0.name) }.joined(separator: " · ")
            return "\(names) \(kindWord(kind))"
        }
        return alerts
            .map { "\(shortLabel(id: $0.id, name: $0.name)) \(kindWord($0.kind))" }
            .joined(separator: " · ")
    }

    public static func body(alerts: [PaceAlertMeterDetail]) -> String {
        alerts.map { detail in
            let used = QuotaPercent.format(detail.percentUsed)
            let elapsed = QuotaPercent.format(detail.elapsedPercent)
            let label = shortLabel(id: detail.id, name: detail.name)
            return "\(kindMark(detail.kind)) \(label) \(used) / \(elapsed)"
        }
        .joined(separator: "\n")
    }

    /// Compact meter name for banners (Cursor / Other / Grok).
    public static func shortLabel(id: String, name: String) -> String {
        switch id {
        case "cursor": return "Cursor"
        case "other": return "Other"
        case "grok": return "Grok"
        default:
            return name
                .replacingOccurrences(of: " Models", with: "")
                .replacingOccurrences(of: " Bot", with: "")
        }
    }

    private static func kindWord(_ kind: PaceAlertKind) -> String {
        switch kind {
        case .quiet: return "quiet"
        case .under: return "under"
        case .over: return "over"
        case .exhausted: return "exhausted"
        }
    }

    private static func kindMark(_ kind: PaceAlertKind) -> String {
        switch kind {
        case .quiet: return "·"
        case .under: return "▼"
        case .over: return "▲"
        case .exhausted: return "✕"
        }
    }
}
