import Foundation

/// Smart-alert corridor endpoints (Settings % knobs). Locked defaults: 25 / 95 / 25 / 95.
public struct PaceAlertThresholds: Equatable, Sendable {
    public var overMaxStartPct: Double
    public var overEmptyBeforePct: Double
    public var underAfterPct: Double
    public var underMinEndPct: Double

    public init(
        overMaxStartPct: Double,
        overEmptyBeforePct: Double,
        underAfterPct: Double,
        underMinEndPct: Double
    ) {
        self.overMaxStartPct = overMaxStartPct
        self.overEmptyBeforePct = overEmptyBeforePct
        self.underAfterPct = underAfterPct
        self.underMinEndPct = underMinEndPct
    }

    public static let `default` = PaceAlertThresholds(
        overMaxStartPct: 25,
        overEmptyBeforePct: 95,
        underAfterPct: 25,
        underMinEndPct: 95
    )
}

public enum PaceAlertKind: Equatable, Sendable {
    case quiet
    case under
    case over
    case exhausted
}

/// Straight-line over/under corridors on the used × elapsed plane.
public enum PaceAlertBands {
    /// Used fraction on the over boundary at elapsed fraction `t`.
    public static func overUsed(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let a = thresholds.overMaxStartPct / 100
        let b = max(thresholds.overEmptyBeforePct / 100, 1e-6)
        return a + ((1 - a) / b) * t
    }

    /// Used fraction on the under boundary at elapsed fraction `t`.
    public static func underUsed(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let c = thresholds.underAfterPct / 100
        let d = thresholds.underMinEndPct / 100
        let denom = max(1 - c, 1e-6)
        return (d / denom) * (t - c)
    }

    public static func evaluate(
        percentUsed: Double,
        elapsedFraction: Double,
        thresholds: PaceAlertThresholds = .default,
        smart: Bool,
        legacyUnder: Double = PaceCalculator.significantLo,
        legacyOver: Double = PaceCalculator.significantHi
    ) -> PaceAlertKind {
        let u = percentUsed / 100
        let t = min(max(elapsedFraction, 1e-6), 1)

        if u >= 1 {
            return .exhausted
        }

        if smart {
            let overLine = overUsed(atElapsed: t, thresholds: thresholds)
            if u > overLine { return .over }

            let c = thresholds.underAfterPct / 100
            if t > c {
                let underLine = underUsed(atElapsed: t, thresholds: thresholds)
                if u < underLine { return .under }
            }
            return .quiet
        }

        let r = u / t
        let lo = min(legacyUnder, legacyOver)
        let hi = max(legacyUnder, legacyOver)
        if r < lo { return .under }
        if r > hi { return .over }
        return .quiet
    }

    public static func isSignificant(kind: PaceAlertKind) -> Bool {
        kind != .quiet
    }
}
