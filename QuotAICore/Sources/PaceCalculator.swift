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
    public static let greenLo = 0.90
    public static let greenHi = 1.10

    public static func pace(
        percentUsed: Double,
        periodStart: Date,
        periodEnd: Date,
        now: Date = Date()
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
        if r < greenLo {
            label = "Under · \(pct)% pace"
        } else if r > greenHi {
            label = "Over · \(pct)% pace"
        } else {
            label = "On pace · \(pct)% pace"
        }
        if early, let d = daysToExhaustion {
            // Days until quota hits 100% at current burn — not days until period reset.
            label += " · empties in ~\(RemainingTime.format(days: d))"
        }

        return PaceResult(ratio: r, label: label, isEarly: early, daysToExhaustion: daysToExhaustion)
    }
}
