import Foundation

/// Pure reader for Cursor (legacy) + Grok (`grok*`) corridor dials.
public enum PaceAlertThresholdStore {
    public static let cursorKeys = [
        "overMaxStartPct",
        "overEmptyBeforePct",
        "underAfterPct",
        "underMinEndPct",
        "overCurvePct",
        "underCurvePct"
    ]

    public static let grokKeys = [
        "grokOverMaxStartPct",
        "grokOverEmptyBeforePct",
        "grokUnderAfterPct",
        "grokUnderMinEndPct",
        "grokOverCurvePct",
        "grokUnderCurvePct"
    ]

    public static func cursor(from ints: [String: Int]) -> PaceAlertThresholds {
        read(
            ints: ints,
            keys: cursorKeys,
            defaults: .default
        )
    }

    public static func grok(from ints: [String: Int]) -> PaceAlertThresholds {
        read(
            ints: ints,
            keys: grokKeys,
            defaults: .grokDefault
        )
    }

    /// Convenience over `UserDefaults`-style Any values (Int only).
    public static func intMap(from defaults: UserDefaults) -> [String: Int] {
        var map: [String: Int] = [:]
        for key in cursorKeys + grokKeys {
            if let value = defaults.object(forKey: key) as? Int {
                map[key] = value
            }
        }
        return map
    }

    private static func read(
        ints: [String: Int],
        keys: [String],
        defaults: PaceAlertThresholds
    ) -> PaceAlertThresholds {
        PaceAlertThresholds(
            overMaxStartPct: Double(ints[keys[0]] ?? Int(defaults.overMaxStartPct)),
            overEmptyBeforePct: Double(ints[keys[1]] ?? Int(defaults.overEmptyBeforePct)),
            underAfterPct: Double(ints[keys[2]] ?? Int(defaults.underAfterPct)),
            underMinEndPct: Double(ints[keys[3]] ?? Int(defaults.underMinEndPct)),
            overCurvePct: Double(ints[keys[4]] ?? Int(defaults.overCurvePct)),
            underCurvePct: Double(ints[keys[5]] ?? Int(defaults.underCurvePct))
        )
    }
}
