import Foundation

/// Menu-bar ring/bar chrome: fill tint + whether it pulses.
public struct PaceChrome: Equatable, Sendable {
    public var tint: SymbolTint
    /// Pulse only for corridor under/over/exhausted when blink is enabled.
    public var blink: Bool

    public init(tint: SymbolTint, blink: Bool) {
        self.tint = tint
        self.blink = blink
    }
}

/// Resolves display chrome from corridor alert kind only.
///
/// - Color: under / over / exhausted → tint; quiet or alerts-off → neutral.
/// - Blink: only when corridor kind is significant and blink is enabled.
public enum PaceChromeResolver {
    public static func resolve(
        corridorKind: PaceAlertKind,
        corridorAlertsEnabled: Bool,
        blinkEnabled: Bool
    ) -> PaceChrome {
        guard corridorAlertsEnabled else {
            return PaceChrome(tint: .neutral, blink: false)
        }
        let tint: SymbolTint
        switch corridorKind {
        case .under: tint = .under
        case .over: tint = .warning
        case .exhausted: tint = .critical
        case .quiet: tint = .neutral
        }
        let blink = blinkEnabled && PaceAlertBands.isSignificant(kind: corridorKind)
        return PaceChrome(tint: tint, blink: blink)
    }
}
