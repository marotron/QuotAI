import Foundation

/// Display formatting for Spending-style usage percentages.
public enum QuotaPercent {
    /// Integer % matching Cursor’s Spending UI (`0.32` → `1`, not `0`).
    public static func display(_ value: Double) -> Int {
        guard value > 0 else { return 0 }
        return Int(value.rounded(.up))
    }

    public static func format(_ value: Double) -> String {
        "\(display(value))%"
    }

    /// Raw API value for the expanded menu (`0.3177…` → `0.32%`).
    public static func precise(_ value: Double) -> String {
        if value == 0 { return "0%" }
        var s = String(format: "%.2f", value)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return "\(s)%"
    }
}
