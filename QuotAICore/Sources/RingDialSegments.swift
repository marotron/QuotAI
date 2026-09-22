import Foundation

/// Pure arc ranges for menu-bar ring dials (proto A/B timeline brand + G pace-under-pale).
public enum RingDialSegments {
    public enum Style: String, Sendable {
        /// Pale track + brand used arc (timeline drawn separately by the compositor).
        case timelineBrand
        /// Pace segments; under-slack is pale ok.
        case paceUnderPale
    }

    public enum Tint: Equatable, Sendable {
        case brand
        case under
        case ok
        /// Pale on-pace slack (G under band only).
        case okPale
        case over
    }

    public struct Arc: Equatable, Sendable {
        public var fromPct: Double
        public var toPct: Double
        public var tint: Tint

        public init(fromPct: Double, toPct: Double, tint: Tint) {
            self.fromPct = fromPct
            self.toPct = toPct
            self.tint = tint
        }
    }

    /// Ordered arcs covering used/elapsed for one quota ring. Pale empty track is not included.
    public static func arcs(
        usedPct: Double,
        elapsedPct: Double,
        style: Style,
        onPaceLo: Double = PaceCalculator.greenLo,
        onPaceHi: Double = PaceCalculator.greenHi
    ) -> [Arc] {
        let used = clampPct(usedPct)
        let elapsed = clampPct(elapsedPct)
        switch style {
        case .timelineBrand:
            guard used > 0 else { return [] }
            return [Arc(fromPct: 0, toPct: used, tint: .brand)]
        case .paceUnderPale:
            return paceUnderPaleArcs(used: used, elapsed: elapsed, onPaceLo: onPaceLo, onPaceHi: onPaceHi)
        }
    }

    private static func paceUnderPaleArcs(
        used: Double,
        elapsed: Double,
        onPaceLo: Double,
        onPaceHi: Double
    ) -> [Arc] {
        // Match proto: floor elapsed for ratio so early-period used still classifies.
        let e = max(elapsed, 0.5)
        let r = used / e
        let lo = min(onPaceLo, onPaceHi)
        let hi = max(onPaceLo, onPaceHi)

        if PaceCalculator.isOnPace(r, lo: lo, hi: hi) {
            guard used > 0 else { return [] }
            return [Arc(fromPct: 0, toPct: used, tint: .ok)]
        }
        if r < lo {
            var arcs: [Arc] = []
            if used > 0 {
                arcs.append(Arc(fromPct: 0, toPct: used, tint: .under))
            }
            if elapsed > used {
                arcs.append(Arc(fromPct: used, toPct: elapsed, tint: .okPale))
            }
            return arcs
        }
        // Over: ok through elapsed, then overage to used.
        var arcs: [Arc] = []
        if elapsed > 0 {
            arcs.append(Arc(fromPct: 0, toPct: elapsed, tint: .ok))
        }
        if used > elapsed {
            arcs.append(Arc(fromPct: elapsed, toPct: used, tint: .over))
        }
        return arcs
    }

    private static func clampPct(_ value: Double) -> Double {
        min(100, max(0, value))
    }
}
