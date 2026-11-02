import Foundation

/// Age-only freshness for refresh badges: color ramp and pie bite progress.
public enum RefreshFreshness {
    /// Hard red past this age (1 hour). Green→amber ramps linearly over 0…cap.
    public static let defaultCap: TimeInterval = 3600

    public enum Tint: Equatable, Sendable {
        /// Mix factor 0 = green end, 1 = amber end.
        case ramp(Double)
        case overdue
    }

    /// Age → green/amber mix, or overdue past `cap`.
    public static func tint(age: TimeInterval, cap: TimeInterval = defaultCap) -> Tint {
        let age = max(0, age)
        guard cap > 0, age < cap else { return .overdue }
        return .ramp(age / cap)
    }

    /// Inverse pie progress: 0 just refreshed (full pie), 1 at/after next poll (empty).
    public static func elapsedFraction(age: TimeInterval, interval: TimeInterval) -> Double {
        guard interval > 0 else { return 1 }
        return min(1, max(0, age / interval))
    }
}
