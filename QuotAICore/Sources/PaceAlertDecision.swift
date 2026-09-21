import Foundation

public struct PaceAlertMeterInput: Equatable, Sendable {
    public var id: String
    public var name: String
    public var percentUsed: Double
    public var elapsedFraction: Double

    public init(id: String, name: String, percentUsed: Double, elapsedFraction: Double) {
        self.id = id
        self.name = name
        self.percentUsed = percentUsed
        self.elapsedFraction = elapsedFraction
    }
}

public struct PaceAlertChannels: Equatable, Sendable {
    public var blink: Bool
    public var notify: Bool
    public var email: Bool

    public init(blink: Bool, notify: Bool, email: Bool) {
        self.blink = blink
        self.notify = notify
        self.email = email
    }
}

public struct PaceAlertDecisionResult: Equatable, Sendable {
    public var shouldBlink: Bool
    public var shouldNotify: Bool
    public var shouldEmail: Bool
    /// Stable, order-independent signature of alerting meters (empty when quiet).
    public var signature: String
    public var alerts: [PaceAlertMeterAlert]

    public init(
        shouldBlink: Bool,
        shouldNotify: Bool,
        shouldEmail: Bool,
        signature: String,
        alerts: [PaceAlertMeterAlert]
    ) {
        self.shouldBlink = shouldBlink
        self.shouldNotify = shouldNotify
        self.shouldEmail = shouldEmail
        self.signature = signature
        self.alerts = alerts
    }
}

public struct PaceAlertMeterAlert: Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: PaceAlertKind

    public init(id: String, name: String, kind: PaceAlertKind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// Combines band evaluation across meters with delivery channel flags.
public enum PaceAlertDecision {
    public static func evaluate(
        meters: [PaceAlertMeterInput],
        thresholds: PaceAlertThresholds = .default,
        smart: Bool,
        legacyUnder: Double = PaceCalculator.significantLo,
        legacyOver: Double = PaceCalculator.significantHi,
        channels: PaceAlertChannels
    ) -> PaceAlertDecisionResult {
        let alerts: [PaceAlertMeterAlert] = meters.compactMap { meter in
            let kind = PaceAlertBands.evaluate(
                percentUsed: meter.percentUsed,
                elapsedFraction: meter.elapsedFraction,
                thresholds: thresholds,
                smart: smart,
                legacyUnder: legacyUnder,
                legacyOver: legacyOver
            )
            guard PaceAlertBands.isSignificant(kind: kind) else { return nil }
            return PaceAlertMeterAlert(id: meter.id, name: meter.name, kind: kind)
        }
        .sorted { $0.id < $1.id }

        let significant = !alerts.isEmpty
        let signature = alerts.map { "\($0.id):\($0.kind.rawValue)" }.joined(separator: "|")

        return PaceAlertDecisionResult(
            shouldBlink: significant && channels.blink,
            shouldNotify: significant && channels.notify,
            shouldEmail: significant && channels.email,
            signature: signature,
            alerts: alerts
        )
    }
}

extension PaceAlertKind {
    fileprivate var rawValue: String {
        switch self {
        case .quiet: return "quiet"
        case .under: return "under"
        case .over: return "over"
        case .exhausted: return "exhausted"
        }
    }
}
