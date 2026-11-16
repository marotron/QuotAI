import Foundation

public enum ElapsedRingSegmentation {
    /// Whole-day windows tolerate a one-hour daylight-saving transition.
    /// Other windows must consist of whole hours. Unusual durations stay continuous.
    public static func count(duration: TimeInterval?) -> Int? {
        guard let duration, duration.isFinite, duration > 0, duration <= 366 * 86400 + 3600 else { return nil }
        let days = (duration / 86400).rounded()
        if days >= 1, days <= 366,
           abs(duration - days * 86400) <= (days == 1 ? 0.5 : 3600) {
            return Int(days)
        }
        let hours = (duration / 3600).rounded()
        guard hours >= 1, hours <= 366, abs(duration - hours * 3600) < 1 else { return nil }
        return Int(hours)
    }

    /// Each pair is a percentage range of a segment, leaving the prototype's wider gaps.
    public static func spans(count: Int, radius: Double) -> [(start: Double, end: Double)] {
        guard count > 0, count <= 366, radius.isFinite, radius > 0 else { return [] }
        let circumference = 2 * Double.pi * radius
        let unit = circumference / Double(count)
        let gap = min(0.65, unit * 0.3)
        return (0..<count).map { index in
            let start = (Double(index) * unit + gap / 2) / circumference * 100
            let end = (Double(index + 1) * unit - gap / 2) / circumference * 100
            return (start: start, end: end)
        }
    }
}
