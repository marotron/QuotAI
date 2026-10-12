import Foundation

/// Menu-bar ring/bar chrome: fill tint + whether it pulses.
public struct PaceChrome: Equatable, Sendable {
    public var tint: SymbolTint
    /// Pulse only for smart under/over/exhausted — on-pace alone stays solid.
    public var blink: Bool

    public init(tint: SymbolTint, blink: Bool) {
        self.tint = tint
        self.blink = blink
    }
}

/// Resolves display chrome when smart pace alerts are on.
///
/// - Color: smart under/over/exhausted wins; quiet falls back to on-pace ratio band.
/// - Blink: only when smart kind is significant (and enabled).
public enum PaceChromeResolver {
    public static func resolve(
        pace: PaceResult?,
        smartKind: PaceAlertKind,
        onPaceLo: Double = PaceCalculator.greenLo,
        onPaceHi: Double = PaceCalculator.greenHi,
        blinkEnabled: Bool
    ) -> PaceChrome {
        let tint = MenuPresenter.tint(
            pace: pace,
            smartKind: smartKind,
            onPaceLo: onPaceLo,
            onPaceHi: onPaceHi
        )
        let blink = blinkEnabled && PaceAlertBands.isSignificant(kind: smartKind)
        return PaceChrome(tint: tint, blink: blink)
    }
}
