import Foundation

/// How often to poll as the soonest quota reset approaches.
/// First matching step wins, and the reset must be strictly under that step's threshold.
public struct RefreshSchedule: Equatable, Sendable, Codable {
    public struct Step: Equatable, Sendable, Codable {
        public var underMinutes: Int
        public var everyMinutes: Int

        public init(underMinutes: Int, everyMinutes: Int) {
            self.underMinutes = underMinutes
            self.everyMinutes = everyMinutes
        }
    }

    public var steps: [Step]
    public var otherwiseMinutes: Int

    public init(steps: [Step], otherwiseMinutes: Int) {
        self.steps = steps
        self.otherwiseMinutes = otherwiseMinutes
    }

    public static let `default` = RefreshSchedule(
        steps: [
            Step(underMinutes: 60, everyMinutes: 1),
            Step(underMinutes: 3 * 60, everyMinutes: 5),
            Step(underMinutes: 6 * 60, everyMinutes: 10),
            Step(underMinutes: 12 * 60, everyMinutes: 15),
            Step(underMinutes: 24 * 60, everyMinutes: 30),
        ],
        otherwiseMinutes: 60
    )

    public func interval(periodEnds: [Date], now: Date) -> TimeInterval {
        guard let soonest = periodEnds.min() else {
            return Self.seconds(otherwiseMinutes)
        }
        let remaining = soonest.timeIntervalSince(now)
        for step in steps where remaining < TimeInterval(step.underMinutes * 60) {
            return Self.seconds(step.everyMinutes)
        }
        return Self.seconds(otherwiseMinutes)
    }

    private static func seconds(_ minutes: Int) -> TimeInterval {
        TimeInterval(max(1, minutes) * 60)
    }

    /// Stored JSON that will not decode, or that breaks the schedule rules, becomes the default.
    public static func fromStoredJSON(_ data: Data) -> RefreshSchedule {
        guard let decoded = try? JSONDecoder().decode(RefreshSchedule.self, from: data),
              decoded.acceptsStoredForm else {
            return .default
        }
        return decoded
    }

    /// Duplicate thresholds, or any interval under a minute, are garbage.
    private var acceptsStoredForm: Bool {
        guard otherwiseMinutes >= 1 else { return false }
        var seen = Set<Int>()
        for step in steps {
            guard step.underMinutes > 0, step.everyMinutes >= 1 else { return false }
            if !seen.insert(step.underMinutes).inserted { return false }
        }
        return true
    }
}

/// How a minute span is shown. The schedule itself stays in minutes.
public enum RefreshUnit: Int, CaseIterable, Sendable {
    case minutes = 1
    case hours = 60
    case days = 1_440

    public var minutes: Int { rawValue }

    public func title(count: Int) -> String {
        switch self {
        case .minutes:
            "min"
        case .hours:
            count == 1 ? "hr" : "hrs"
        case .days:
            count == 1 ? "day" : "days"
        }
    }
}

public struct RefreshDuration: Equatable, Sendable {
    public var count: Int
    public var unit: RefreshUnit

    public var minutes: Int { count * unit.minutes }

    public init(count: Int, unit: RefreshUnit) {
        self.count = max(1, count)
        self.unit = unit
    }

    /// Largest unit that divides `minutes` exactly: 1,440 → 1 day, 180 → 3 hrs, 45 → 45 min.
    public static func fitting(_ minutes: Int) -> RefreshDuration {
        let safe = max(1, minutes)
        for unit in [RefreshUnit.days, .hours] where safe.isMultiple(of: unit.minutes) {
            return RefreshDuration(count: safe / unit.minutes, unit: unit)
        }
        return RefreshDuration(count: safe, unit: .minutes)
    }

    /// Same span in `unit` when it divides evenly; otherwise the nearest count, at least 1.
    public func converted(to unit: RefreshUnit) -> RefreshDuration {
        guard unit != self.unit else { return self }
        let exact = Double(minutes) / Double(unit.minutes)
        return RefreshDuration(count: max(1, Int(exact.rounded())), unit: unit)
    }
}
