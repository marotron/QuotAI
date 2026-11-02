import Foundation

/// Pure hover-tip clock + placement helpers for the pace history chart.
public enum PaceHistoryTipPresentation {
    public struct PeriodAnchor: Equatable, Sendable {
        public var periodStart: Date
        public var periodDuration: TimeInterval

        public init(periodStart: Date, periodDuration: TimeInterval) {
            self.periodStart = periodStart
            self.periodDuration = periodDuration
        }
    }

    /// Cursor + Other share one billing window; Grok has its own.
    public enum BillingFamily: String, CaseIterable, Sendable {
        case cursor
        case grok

        public var tipPrefix: String {
            switch self {
            case .cursor: return "Cursor"
            case .grok: return "Grok"
            }
        }
    }

    public struct WhenReading: Equatable, Sendable {
        /// Set when more than one billing family is visible (so the tip can label each line).
        public var family: BillingFamily?
        public var at: Date

        public init(family: BillingFamily?, at: Date) {
            self.family = family
            self.at = at
        }
    }

    public static func billingFamily(for id: PaceHistoryMeterId) -> BillingFamily {
        id == .grok ? .grok : .cursor
    }

    /// Infer billing window from the latest sample (periodStart + elapsed → duration).
    public static func periodAnchor(from samples: [PaceHistorySample]) -> PeriodAnchor? {
        guard let sample = samples.last, sample.elapsedPct > 0.5 else { return nil }
        let elapsedFrac = sample.elapsedPct / 100
        let elapsed = sample.timestamp.timeIntervalSince(sample.periodStart)
        guard elapsed > 0, elapsedFrac > 0 else { return nil }
        return PeriodAnchor(periodStart: sample.periodStart, periodDuration: elapsed / elapsedFrac)
    }

    public static func date(atElapsedPct elapsed: Double, anchor: PeriodAnchor) -> Date {
        anchor.periodStart.addingTimeInterval((elapsed / 100) * anchor.periodDuration)
    }

    /// Relative age copy — same thresholds as the menu status ago badges.
    public static func relativeAgo(from: Date, to: Date) -> String {
        let ms = max(0, to.timeIntervalSince(from) * 1000)
        if ms < 45_000 { return "just now" }
        let mins = Int((ms / 60_000).rounded())
        if mins < 60 { return "\(mins)m ago" }
        let hrs = Int((Double(mins) / 60).rounded())
        if hrs < 36 { return "\(hrs)h ago" }
        let days = Int((Double(hrs) / 24).rounded())
        return "\(days)d ago"
    }

    /// One reading when a single billing family is visible; Cursor + Grok when both appear.
    public static func whenReadings(
        elapsedPct: Double,
        visibleMeterIds: [PaceHistoryMeterId],
        anchorsByFamily: [BillingFamily: PeriodAnchor]
    ) -> [WhenReading] {
        let families = orderedFamilies(in: visibleMeterIds)
        let labelFamilies = families.count > 1
        return families.compactMap { family in
            guard let anchor = anchorsByFamily[family] else { return nil }
            return WhenReading(
                family: labelFamilies ? family : nil,
                at: date(atElapsedPct: elapsedPct, anchor: anchor)
            )
        }
    }

    /// Tip leading X relative to plot origin. Flips left of the guide once elapsed ≥ 50%.
    public static func tipLeadingX(
        elapsedPct: Double,
        plotWidth: Double,
        tipWidth: Double,
        gap: Double = 8
    ) -> Double {
        let guide = (elapsedPct / 100) * plotWidth
        if elapsedPct >= 50 {
            return guide - tipWidth - gap
        }
        return guide + gap
    }

    private static func orderedFamilies(in meterIds: [PaceHistoryMeterId]) -> [BillingFamily] {
        var seen = Set<BillingFamily>()
        var out: [BillingFamily] = []
        for id in meterIds {
            let family = billingFamily(for: id)
            if seen.insert(family).inserted {
                out.append(family)
            }
        }
        return out
    }
}
