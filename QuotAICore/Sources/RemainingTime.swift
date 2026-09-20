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

    /// Expanded menu: `29d 14h`, `5h 12m`, `4m`.
    public static func formatDetailed(seconds: TimeInterval) -> String {
        let remaining = max(0, seconds)
        let days = Int(remaining / day)
        let hours = Int(remaining.truncatingRemainder(dividingBy: day) / hour)
        let mins = Int(remaining.truncatingRemainder(dividingBy: hour) / minute)
        if days > 0 {
            return hours > 0 ? "\(days)d \(hours)h" : "\(days)d"
        }
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }

    /// Pace early-depletion uses fractional days.
    public static func format(days: Double) -> String {
        format(seconds: days * day)
    }
}
