import Foundation

/// Display-only downsample for the pace-history chart.
///
/// Disk history stays full-resolution; this reducer is applied before mark
/// construction so the first Charts layout does not fan out thousands of
/// `LineMark`/`PointMark` rows.
public enum PaceHistoryChartDownsample {
    /// Maximum points drawn per series in the chart marks.
    public static let maxPoints = 200
    /// Vertical resolution for chart marks, in percent (1 % steps).
    public static let yResolution = 1.0

    /// Downsamples the samples needed to draw `domain`.
    ///
    /// Includes one source sample on each side where available. That lets a
    /// chart clip the line cleanly at the visible domain edges while assigning
    /// the full point budget to the zoomed portion of the history.
    public static func downsample(
        samples: [PaceHistorySample],
        domain: ClosedRange<Double>,
        maxPoints: Int = Self.maxPoints,
        yResolution: Double = Self.yResolution
    ) -> [PaceHistorySample] {
        guard !samples.isEmpty else { return [] }

        let firstAtOrAfterLower = samples.firstIndex {
            $0.elapsedPct >= domain.lowerBound
        } ?? samples.endIndex
        let lastAtOrBeforeUpper = samples.lastIndex {
            $0.elapsedPct <= domain.upperBound
        } ?? samples.startIndex - 1

        let lowerIndex = max(samples.startIndex, firstAtOrAfterLower - 1)
        let upperIndex = min(samples.index(before: samples.endIndex), lastAtOrBeforeUpper + 1)
        guard lowerIndex <= upperIndex else { return [] }

        return downsample(
            samples: Array(samples[lowerIndex...upperIndex]),
            maxPoints: maxPoints,
            yResolution: yResolution
        )
    }

    /// Largest Triangle Three Buckets (LTTB) downsample.
    ///
    /// - Keeps the first and last sample.
    /// - Buckets the interior into `maxPoints - 2` buckets.
    /// - Picks, per bucket, the sample that forms the largest triangle with
    ///   the previously selected point and the average of the next bucket.
    /// - Rounds `usedPct` to the nearest `yResolution` percent.
    /// - Returns `samples` unchanged when `samples.count <= maxPoints`.
    /// - Returns an empty array for empty input.
    ///
    /// Output `elapsedPct` is strictly increasing because input samples are
    /// assumed to be ordered by `elapsedPct` and each bucket is processed left
    /// to right with a single selection per bucket.
    public static func downsample(
        samples: [PaceHistorySample],
        maxPoints: Int = Self.maxPoints,
        yResolution: Double = Self.yResolution
    ) -> [PaceHistorySample] {
        guard samples.count > maxPoints else {
            return samples.map { rounded($0, resolution: yResolution) }
        }
        guard maxPoints >= 3, let first = samples.first, let last = samples.last else {
            return samples
        }

        let bucketCount = maxPoints - 2
        let interiorCount = samples.count - 2
        let bucketSize = Double(interiorCount) / Double(bucketCount)

        var selected: [PaceHistorySample] = [rounded(first, resolution: yResolution)]
        var previousIndex = 0

        for bucket in 0..<bucketCount {
            let startIndex = 1 + Int(floor(Double(bucket) * bucketSize))
            let endIndex = 1 + min(
                interiorCount,
                Int(floor(Double(bucket + 1) * bucketSize))
            )
            let nextBucketStart = endIndex
            let nextBucketEnd = 1 + min(
                interiorCount,
                Int(floor(Double(bucket + 2) * bucketSize))
            )

            let range = startIndex..<min(endIndex, samples.count - 1)
            let nextRange = nextBucketStart..<min(nextBucketEnd, samples.count - 1)
            let avgNext = averagePoint(in: samples, range: nextRange)

            var bestIndex = range.lowerBound
            var bestArea = -Double.infinity
            let previous = samples[previousIndex]

            for index in range {
                let point = samples[index]
                let area = triangleArea(
                    a: (previous.elapsedPct, previous.usedPct),
                    b: (point.elapsedPct, point.usedPct),
                    c: avgNext
                )
                if area > bestArea {
                    bestArea = area
                    bestIndex = index
                }
            }

            selected.append(rounded(samples[bestIndex], resolution: yResolution))
            previousIndex = bestIndex
        }

        selected.append(rounded(last, resolution: yResolution))
        return selected
    }

    private static func averagePoint(
        in samples: [PaceHistorySample],
        range: Range<Int>
    ) -> (Double, Double) {
        guard !range.isEmpty else {
            let last = samples[samples.count - 1]
            return (last.elapsedPct, last.usedPct)
        }
        var sumElapsed = 0.0
        var sumUsed = 0.0
        for index in range {
            sumElapsed += samples[index].elapsedPct
            sumUsed += samples[index].usedPct
        }
        let count = Double(range.count)
        return (sumElapsed / count, sumUsed / count)
    }

    private static func triangleArea(
        a: (Double, Double),
        b: (Double, Double),
        c: (Double, Double)
    ) -> Double {
        abs(
            (a.0 * (b.1 - c.1)) +
            (b.0 * (c.1 - a.1)) +
            (c.0 * (a.1 - b.1))
        ) * 0.5
    }

    private static func rounded(
        _ sample: PaceHistorySample,
        resolution: Double
    ) -> PaceHistorySample {
        guard resolution > 0 else { return sample }
        var copy = sample
        copy.usedPct = (sample.usedPct / resolution).rounded() * resolution
        return copy
    }
}
