import Foundation

/// Formats time until reset / exhaustion: `Nd` ≥ 1 day, `Nh` ≥ 1 hour, otherwise `Nm`.
public enum RemainingTime {
    public static let day: TimeInterval = 86_400
    public static let hour: TimeInterval = 3_600
    public static let minute: TimeInterval = 60

    /// Compact time to reset. Partial units round down (`45.6m` → `45m`).
    public static func format(seconds: TimeInterval) -> String {
        labeled(max(0, seconds), roundingUp: false)
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

    /// Pace early-depletion uses fractional days. A partial unit still counts.
    public static func format(days: Double) -> String {
        labeled(max(0, days) * day, roundingUp: true)
    }

    private static func labeled(_ remaining: TimeInterval, roundingUp: Bool) -> String {
        func count(_ span: TimeInterval) -> Int {
            let units = remaining / span
            return roundingUp ? Int(ceil(units)) : Int(units)
        }
        if remaining >= day { return "\(count(day))d" }
        if remaining >= hour { return "\(count(hour))h" }
        return "\(count(minute))m"
    }
}
