import Foundation

/// Locked burn-rate formula — see docs/pr.md / issues/04-burn-rate-formula.md
public struct PaceResult: Equatable, Sendable {
    public var ratio: Double?
    public var label: String
    public var isEarly: Bool
    public var daysToExhaustion: Double?

    public init(ratio: Double?, label: String, isEarly: Bool, daysToExhaustion: Double?) {
        self.ratio = ratio
        self.label = label
        self.isEarly = isEarly
        self.daysToExhaustion = daysToExhaustion
    }
}

public enum PaceCalculator {
    /// Default on-pace dead zone (±10% around 100% burn). Common tolerance for “on track”.
    public static let greenLo = 0.90
    public static let greenHi = 1.10
    /// Clear of the default green band — default menu-bar blink alert thresholds (ratios).
    public static let significantLo = 0.75
    public static let significantHi = 1.30

    /// Ratio inside the on-pace dead zone (inclusive).
    public static func isOnPace(
        _ ratio: Double,
        lo: Double = greenLo,
        hi: Double = greenHi
    ) -> Bool {
        let a = min(lo, hi)
        let b = max(lo, hi)
        return ratio >= a && ratio <= b
    }

    /// Exhausted, or ratio outside the configured under/over band.
    public static func isSignificant(
        pace: PaceResult?,
        under: Double = significantLo,
        over: Double = significantHi
    ) -> Bool {
        guard let pace else { return false }
        if pace.daysToExhaustion == 0 { return true }
        guard let r = pace.ratio else { return false }
        let lo = min(under, over)
        let hi = max(under, over)
        return r < lo || r > hi
    }

    public static func pace(
        percentUsed: Double,
        periodStart: Date,
        periodEnd: Date,
        now: Date = Date(),
        onPaceLo: Double = greenLo,
        onPaceHi: Double = greenHi
    ) -> PaceResult {
        if percentUsed >= 100 {
            return PaceResult(ratio: nil, label: "Exhausted", isEarly: false, daysToExhaustion: 0)
        }

        let total = periodEnd.timeIntervalSince(periodStart)
        guard total > 0 else {
            return PaceResult(ratio: nil, label: "Pace n/a", isEarly: false, daysToExhaustion: nil)
        }

        // ε ≈ one hour on a ~30-day period
        let epsilon = total / (24 * 30)
        let elapsed = max(now.timeIntervalSince(periodStart), epsilon)
        let t = min(max(elapsed / total, 1e-6), 1.0)
        let r = (percentUsed / 100.0) / t

        let daysElapsed = max(elapsed / 86_400.0, 1e-6)
        let burn = percentUsed / daysElapsed
        let daysToExhaustion: Double? = burn > 0 ? (100.0 - percentUsed) / burn : nil
        let early: Bool = {
            guard let d = daysToExhaustion else { return false }
            return now.addingTimeInterval(d * 86_400) < periodEnd
        }()

        let pct = Int((r * 100).rounded())
        var label: String
        if isOnPace(r, lo: onPaceLo, hi: onPaceHi) {
            label = "On pace · \(pct)% pace"
        } else if r < min(onPaceLo, onPaceHi) {
            label = "Under · \(pct)% pace"
        } else {
            label = "Over · \(pct)% pace"
        }
        if early, let d = daysToExhaustion {
            // Days until quota hits 100% at current burn — not days until period reset.
            label += " · empties in ~\(RemainingTime.format(days: d))"
        }

        return PaceResult(ratio: r, label: label, isEarly: early, daysToExhaustion: daysToExhaustion)
    }
}
