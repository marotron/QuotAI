import Foundation

/// Shared menu + Settings status line for dual last-refresh times.
public enum LastRefreshStatus {
    public static func line(
        cursor: Date?,
        grok: Date?,
        isRefreshing: Bool,
        formatTime: (Date) -> String
    ) -> String {
        if isRefreshing {
            return "Refreshing…"
        }
        let cursorText = cursor.map(formatTime) ?? "—"
        let grokText = grok.map(formatTime) ?? "—"
        return "Last refresh: Cursor \(cursorText) · Grok Bot \(grokText)"
    }

    /// 24-hour `HH:mm` in the given calendar/time zone (defaults: current).
    public static func format24Hour(
        _ date: Date,
        calendar: Calendar = .current
    ) -> String {
        // Calendar hour is 0…23 — independent of locale 12-hour display prefs.
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return String(format: "%02d:%02d", hour, minute)
    }
}
