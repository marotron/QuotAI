import Foundation
import QuotAICore

/// First successful fetch per local calendar day wins for pace display.
enum PaceSampleStore {
    private static let defaults = UserDefaults.standard

    struct Sample: Codable, Equatable {
        var percentUsed: Double
        var sampledAt: Date
        var periodStart: Date
        var periodEnd: Date
    }

    enum MeterKey: String {
        case cursorModels
        case otherModels
        case grokBot
    }

    static func resolvePace(for meter: QuotaMeter, key: MeterKey, now: Date = Date(), calendar: Calendar = .current) -> QuotaMeter {
        guard !meter.isUnavailable,
              let pct = meter.percentUsed,
              let start = meter.periodStart,
              let end = meter.periodEnd else {
            return meter
        }

        // Same local day only; drop the sample when the billing period rolls over mid-day.
        if let existing = load(key),
           calendar.isDate(existing.sampledAt, inSameDayAs: now),
           existing.periodStart == start,
           existing.periodEnd == end {
            var updated = meter
            updated.pace = PaceCalculator.pace(
                percentUsed: existing.percentUsed,
                periodStart: existing.periodStart,
                periodEnd: existing.periodEnd,
                now: now
            )
            return updated
        }

        save(
            Sample(percentUsed: pct, sampledAt: now, periodStart: start, periodEnd: end),
            key: key
        )
        return meter
    }

    private static func load(_ key: MeterKey) -> Sample? {
        guard let data = defaults.data(forKey: storageKey(key)) else { return nil }
        return try? JSONDecoder().decode(Sample.self, from: data)
    }

    private static func save(_ sample: Sample, key: MeterKey) {
        guard let data = try? JSONEncoder().encode(sample) else { return }
        defaults.set(data, forKey: storageKey(key))
    }

    private static func storageKey(_ key: MeterKey) -> String {
        "paceSample.\(key.rawValue)"
    }
}
