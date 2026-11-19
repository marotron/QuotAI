import Foundation

/// Vertical offsets for pace-chart end Icons/Labels so nearby tips do not stack.
/// Tip dots stay on true data; only annotation chrome moves (SwiftUI Y: + down).
public enum PaceHistoryEndAnnotationLayout {
    public struct End: Equatable, Sendable {
        public var id: PaceHistoryMeterId
        public var elapsedPct: Double
        public var usedPct: Double

        public init(id: PaceHistoryMeterId, elapsedPct: Double, usedPct: Double) {
            self.id = id
            self.elapsedPct = elapsedPct
            self.usedPct = usedPct
        }
    }

    /// Default gap between annotation centers in plot points (~10pt icon + breathing room).
    public static let defaultMinSeparation: Double = 16

    /// Returns per-meter Y offsets. Empty when there is nothing to place.
    public static func offsetsY(
        ends: [End],
        plotWidth: Double,
        plotHeight: Double,
        xDomain: ClosedRange<Double> = 0...100,
        yDomain: ClosedRange<Double> = 0...100,
        minSeparation: Double = defaultMinSeparation
    ) -> [PaceHistoryMeterId: Double] {
        guard !ends.isEmpty, plotWidth > 0, plotHeight > 0, minSeparation > 0 else {
            return [:]
        }
        let xSpan = max(xDomain.upperBound - xDomain.lowerBound, 1e-9)
        let ySpan = max(yDomain.upperBound - yDomain.lowerBound, 1e-9)

        struct Pt {
            var id: PaceHistoryMeterId
            var x: Double
            var y: Double
        }

        var pts = ends.map { end in
            let xFrac = (end.elapsedPct - xDomain.lowerBound) / xSpan
            let yFrac = (end.usedPct - yDomain.lowerBound) / ySpan
            return Pt(
                id: end.id,
                x: xFrac * plotWidth,
                // SVG / SwiftUI plot: used 100% at top → smaller Y.
                y: plotHeight - yFrac * plotHeight
            )
        }
        pts.sort { a, b in
            if a.y != b.y { return a.y < b.y }
            return a.id.rawValue < b.id.rawValue
        }

        var offsets: [PaceHistoryMeterId: Double] = [:]
        for p in pts { offsets[p.id] = 0 }

        for i in 0..<pts.count {
            for j in 0..<i {
                let dx = pts[i].x - pts[j].x
                let yi = pts[i].y + (offsets[pts[i].id] ?? 0)
                let yj = pts[j].y + (offsets[pts[j].id] ?? 0)
                let dy = yi - yj
                if hypot(dx, dy) >= minSeparation { continue }
                let need = sqrt(max(0, minSeparation * minSeparation - dx * dx))
                let push = yj + need - pts[i].y
                offsets[pts[i].id] = max(offsets[pts[i].id] ?? 0, push)
            }
        }
        return offsets
    }
}
