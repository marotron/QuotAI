import Foundation

/// Smart-alert corridor endpoints + curve dials (Settings knobs).
/// Locked endpoint defaults: 25 / 95 / 25 / 95. Curve dials default 0 = linear.
public struct PaceAlertThresholds: Equatable, Sendable {
    public var overMaxStartPct: Double
    public var overEmptyBeforePct: Double
    public var underAfterPct: Double
    public var underMinEndPct: Double
    /// 0 = linear (p=1), 100 = parabolic (p=2). Over uses s^p.
    public var overCurvePct: Double
    /// 0 = linear (p=1), 100 = parabolic (p=2). Under mirrors over across even pace (s^(1/p)).
    public var underCurvePct: Double

    public init(
        overMaxStartPct: Double,
        overEmptyBeforePct: Double,
        underAfterPct: Double,
        underMinEndPct: Double,
        overCurvePct: Double = 0,
        underCurvePct: Double = 0
    ) {
        self.overMaxStartPct = overMaxStartPct
        self.overEmptyBeforePct = overEmptyBeforePct
        self.underAfterPct = underAfterPct
        self.underMinEndPct = underMinEndPct
        self.overCurvePct = overCurvePct
        self.underCurvePct = underCurvePct
    }

    public static let `default` = PaceAlertThresholds(
        overMaxStartPct: 25,
        overEmptyBeforePct: 95,
        underAfterPct: 25,
        underMinEndPct: 95,
        overCurvePct: 0,
        underCurvePct: 0
    )
}

public enum PaceAlertKind: Equatable, Sendable {
    case quiet
    case under
    case over
    case exhausted
}

/// Over/under corridors on the used × elapsed plane (linear → parabolic via curve dials).
public enum PaceAlertBands {
    /// Map 0…100 curve dial → power p (1 = linear, 2 = parabolic).
    public static func curvePower(_ curvePct: Double) -> Double {
        1 + min(max(curvePct / 100, 0), 1)
    }

    /// Floor for over: parallel to even pace through Full quota before `(b, 1)` → `u = t + (1 − b)`.
    public static func overFloor(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let b = max(thresholds.overEmptyBeforePct / 100, 1e-6)
        return t + (1 - b)
    }

    /// Ceiling for under: parallel to even pace through Min usage by period end `(1, d)` → `u = t + (d − 1)`.
    public static func underCeiling(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let d = thresholds.underMinEndPct / 100
        return t + (d - 1)
    }

    /// Used fraction on the over boundary at elapsed fraction `t`.
    /// Endpoints (0, a) → (b, 1); `u = a + (1−a)·(t/b)^p`, clamped ≥ parallel through Full quota before.
    public static func overUsed(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let a = thresholds.overMaxStartPct / 100
        let b = max(thresholds.overEmptyBeforePct / 100, 1e-6)
        let p = curvePower(thresholds.overCurvePct)
        let s = max(t / b, 0)
        let raw = a + (1 - a) * pow(s, p)
        return max(raw, overFloor(atElapsed: t, thresholds: thresholds))
    }

    /// Used fraction on the under boundary at elapsed fraction `t`.
    /// Mirror of over across even pace: endpoints (c, 0) → (1, d);
    /// `u = d·((t−c)/(1−c))^(1/p)`, clamped ≤ parallel through Min usage by period end.
    public static func underUsed(atElapsed t: Double, thresholds: PaceAlertThresholds = .default) -> Double {
        let c = thresholds.underAfterPct / 100
        let d = thresholds.underMinEndPct / 100
        let denom = max(1 - c, 1e-6)
        let p = curvePower(thresholds.underCurvePct)
        let s = max((t - c) / denom, 0)
        let raw = d * pow(s, 1 / p)
        return min(raw, underCeiling(atElapsed: t, thresholds: thresholds))
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
