import Foundation

/// Local-clock quiet hours use a half-open interval; equal times disable the window.
public enum AutomaticRefreshPolicy {
    public static func isQuiet(now: Date, enabled: Bool, startMinute: Int, endMinute: Int,
                               calendar: Calendar = .current) -> Bool {
        guard enabled, (0..<1440).contains(startMinute), (0..<1440).contains(endMinute),
              startMinute != endMinute else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return startMinute < endMinute
            ? minute >= startMinute && minute < endMinute
            : minute >= startMinute || minute < endMinute
    }

    /// A usable reading can activate a rule only until its known future reset.
    public static func thresholdEnd(meter: QuotaMeter, threshold: Int, now: Date) -> Date? {
        guard !meter.isUnavailable, let used = meter.percentUsed, used.isFinite,
              used >= Double(threshold), let end = meter.periodEnd, end > now else { return nil }
        return end
    }
}
