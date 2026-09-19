import Foundation

/// Formats time until reset / exhaustion: `Nd` ≥ 1 day, `Nh` ≥ 1 hour, otherwise `Nm`.
public enum RemainingTime {
    public static let day: TimeInterval = 86_400
    public static let hour: TimeInterval = 3_600
    public static let minute: TimeInterval = 60

    public static func format(seconds: TimeInterval) -> String {
        let remaining = max(0, seconds)
        if remaining >= day {
            return "\(Int(ceil(remaining / day)))d"
        }
        if remaining >= hour {
            return "\(Int(ceil(remaining / hour)))h"
        }
        return "\(Int(ceil(remaining / minute)))m"
    }

    /// Pace early-depletion uses fractional days.
    public static func format(days: Double) -> String {
        format(seconds: days * day)
    }
}
