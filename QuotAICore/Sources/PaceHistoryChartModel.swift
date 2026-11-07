import Foundation

/// Toggleable corridor / reference layers on the pace history chart.
public enum PaceHistoryChartLayer: String, CaseIterable, Hashable, Sendable {
    case over
    case under
    case even
    case names
    case icons
    /// Soft discrepancy bands / strip filter (`"disc"` in the hidden-layers CSV).
    case disc
}

/// One point on the used % × elapsed % plane (both 0…100).
public struct PaceHistoryChartPoint: Equatable, Sendable {
    public var elapsedPct: Double
    public var usedPct: Double

    public init(elapsedPct: Double, usedPct: Double) {
        self.elapsedPct = elapsedPct
        self.usedPct = usedPct
    }
}

/// Pure geometry for panel chart corridors (SwiftUI stays dumb).
public enum PaceHistoryChartModel {
    public static let defaultStride: Double = 0.02

    /// Elapsed fraction samples 0…1 inclusive, with optional endpoint inserts for corridor starts.
    public static func elapsedSamples(
        stride step: Double = defaultStride,
        extra: [Double] = []
    ) -> [Double] {
        var pts = Array(stride(from: 0.0, through: 1.0, by: step))
        for t in extra where t >= 0 && t <= 1 {
            if !pts.contains(where: { abs($0 - t) < 1e-9 }) {
                pts.append(t)
            }
        }
        return pts.sorted()
    }

    /// Over-alert boundary (used %) for each elapsed sample ≤ `overEmptyBefore`.
    public static func overBoundary(
        thresholds: PaceAlertThresholds,
        stride step: Double = defaultStride
    ) -> [PaceHistoryChartPoint] {
        let b = thresholds.overEmptyBeforePct / 100
        let samples = elapsedSamples(stride: step, extra: [b]).filter { $0 <= b + 1e-12 }
        return samples.map { t in
            PaceHistoryChartPoint(
                elapsedPct: t * 100,
                usedPct: clampPct(PaceAlertBands.overUsed(atElapsed: t, thresholds: thresholds) * 100)
            )
        }
    }

    /// Under-alert boundary (used %) for each elapsed sample ≥ `underAfter`.
    public static func underBoundary(
        thresholds: PaceAlertThresholds,
        stride step: Double = defaultStride
    ) -> [PaceHistoryChartPoint] {
        let c = thresholds.underAfterPct / 100
        let samples = elapsedSamples(stride: step, extra: [c]).filter { $0 >= c - 1e-12 }
        return samples.map { t in
            let used: Double
            if t < c {
                used = 0
            } else {
                used = clampPct(PaceAlertBands.underUsed(atElapsed: t, thresholds: thresholds) * 100)
            }
            return PaceHistoryChartPoint(elapsedPct: t * 100, usedPct: used)
        }
    }

    public static func evenPaceDiagonal(stride step: Double = defaultStride) -> [PaceHistoryChartPoint] {
        elapsedSamples(stride: step).map { t in
            PaceHistoryChartPoint(elapsedPct: t * 100, usedPct: t * 100)
        }
    }

    /// Layers that should paint given the legend filter set (empty → none).
    public static func visibleLayers(from filters: Set<PaceHistoryChartLayer>) -> Set<PaceHistoryChartLayer> {
        filters
    }

    private static func clampPct(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }
}

/// Hover tip interpolation — matches prototype `interpolateUsed`.
public enum PaceHistoryInterpolation {
    /// Linear interpolate used % at `elapsedPct` along sorted series points.
    /// Returns `nil` when outside the series span or the series is empty.
    public static func usedPct(
        samples: [PaceHistoryChartPoint],
        atElapsed elapsedPct: Double
    ) -> Double? {
        guard !samples.isEmpty else { return nil }
        let first = samples[0].elapsedPct
        let last = samples[samples.count - 1].elapsedPct
        if elapsedPct < first || elapsedPct > last { return nil }
        if samples.count == 1 { return samples[0].usedPct }

        for i in 0..<(samples.count - 1) {
            let e0 = samples[i].elapsedPct
            let u0 = samples[i].usedPct
            let e1 = samples[i + 1].elapsedPct
            let u1 = samples[i + 1].usedPct
            if elapsedPct >= e0 && elapsedPct <= e1 {
                if e1 == e0 { return u0 }
                let t = (elapsedPct - e0) / (e1 - e0)
                return u0 + t * (u1 - u0)
            }
        }
        return samples[samples.count - 1].usedPct
    }
}
