import Foundation

/// Pure X-domain math for menu pace-history chart zoom (elapsed % only).
public enum PaceHistoryChartZoom {
    public static let maxZoom: Double = 10
    /// Minimum visible elapsed span at ×`maxZoom` (`100 / maxZoom`).
    public static let minSpan: Double = 100 / maxZoom
    public static let fullDomain: ClosedRange<Double> = 0...100

    /// Today's full-range axis marks (83.5 / 87.5 are label-only title strips).
    public static let fullAxisTickValues: [Double] = [0, 25, 50, 75, 83.5, 87.5]

    public static func isValidSelection(span: Double) -> Bool {
        span >= minSpan - 1e-9
    }

    public static func zoomFactor(_ range: ClosedRange<Double>) -> Double {
        let span = max(range.upperBound - range.lowerBound, 1e-9)
        return 100 / span
    }

    /// True when the domain is meaningfully tighter than the full 0…100 plane.
    public static func isZoomed(_ range: ClosedRange<Double>) -> Bool {
        range.lowerBound > 0.05 || range.upperBound < 99.95
    }

    /// Keep `range` inside 0…100 and enforce at least `minSpan` (nested ×10 cap).
    public static func clamp(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        var x0 = range.lowerBound
        var x1 = range.upperBound
        if x1 < x0 { swap(&x0, &x1) }

        var span = x1 - x0
        if span < minSpan {
            let mid = (x0 + x1) / 2
            x0 = mid - minSpan / 2
            x1 = mid + minSpan / 2
            span = minSpan
        }

        if x0 < 0 {
            x1 -= x0
            x0 = 0
        }
        if x1 > 100 {
            x0 -= x1 - 100
            x1 = 100
        }

        x0 = max(0, x0)
        x1 = min(100, x1)

        if x1 - x0 < minSpan {
            if x0 <= 0 {
                return 0...minSpan
            }
            return (100 - minSpan)...100
        }
        return x0...x1
    }

    /// Full domain → today's label-hack ticks; zoomed → nice numeric steps (2 / 5 / 10 / 25).
    public static func xAxisTickValues(domain: ClosedRange<Double>) -> [Double] {
        if !isZoomed(domain) {
            return fullAxisTickValues
        }

        let span = domain.upperBound - domain.lowerBound
        let step: Double
        if span <= 12 {
            step = 2
        } else if span <= 25 {
            step = 5
        } else if span <= 50 {
            step = 10
        } else {
            step = 25
        }

        let start = (domain.lowerBound / step).rounded(.up) * step
        var ticks: [Double] = []
        var t = start
        while t <= domain.upperBound + 1e-9 {
            ticks.append((t * 10_000).rounded() / 10_000)
            t += step
        }
        return ticks
    }
}
