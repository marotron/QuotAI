import Foundation

/// Live billing-window length helpers for Settings badge + dial/chart tips.
/// Always `periodEnd − periodStart` — never invent a fixed week/month.
public enum PeriodDuration {
    public static func length(periodStart: Date?, periodEnd: Date?) -> TimeInterval? {
        guard let start = periodStart, let end = periodEnd else { return nil }
        let seconds = end.timeIntervalSince(start)
        guard seconds > 0 else { return nil }
        return seconds
    }

    /// Light badge copy: whole days when near-integer, otherwise one decimal.
    public static func badgeLabel(seconds: TimeInterval) -> String {
        let days = max(seconds, 0) / RemainingTime.day
        if abs(days - days.rounded()) < 0.05 {
            return "\(Int(days.rounded())) days"
        }
        let rounded = (days * 10).rounded() / 10
        return String(format: "%.1f days", rounded)
    }

    /// Timeline dial drag tip: `Xd Yh elapsed · Xd Yh left`.
    public static func dialTimelineTip(dialPct: Int, periodLength: TimeInterval) -> String {
        let fraction = min(max(Double(dialPct) / 100, 0), 1)
        let elapsed = RemainingTime.formatDetailed(seconds: periodLength * fraction)
        let left = RemainingTime.formatDetailed(seconds: periodLength * (1 - fraction))
        return "\(elapsed) elapsed · \(left) left"
    }

    /// Chart hover / tip suffix when the focused period length is known.
    public static func timeLeftLabel(elapsedFraction: Double, periodLength: TimeInterval?) -> String? {
        guard let periodLength, periodLength > 0 else { return nil }
        let t = min(max(elapsedFraction, 0), 1)
        let label = RemainingTime.formatDetailed(seconds: periodLength * (1 - t))
        return "\(label) left"
    }
}
