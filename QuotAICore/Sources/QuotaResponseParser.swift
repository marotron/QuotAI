import Foundation

public enum QuotaParseError: Error, Equatable, Sendable {
    case invalidJSON
    case missingCursorModelsPercent
}

/// Pure Connect JSON → `QuotaMeter`. Network stays in the app target.
public enum QuotaResponseParser {
    public static func cursorModels(from data: Data, now: Date = Date()) throws -> QuotaMeter {
        let root = try decodeObject(data)
        guard let plan = root["planUsage"] as? [String: Any],
              let auto = doubleValue(plan["autoPercentUsed"]) else {
            throw QuotaParseError.missingCursorModelsPercent
        }
        return periodMeter(name: "Cursor Models", percent: auto, root: root, now: now)
    }

    /// Same response / billing cycle as Cursor Models; `apiPercentUsed` (dashboard "Other Models").
    public static func otherModels(from data: Data, now: Date = Date()) throws -> QuotaMeter {
        let root = try decodeObject(data)
        guard let plan = root["planUsage"] as? [String: Any],
              let api = doubleValue(plan["apiPercentUsed"]) else {
            return QuotaMeter(name: "Other Models", isUnavailable: true)
        }
        return periodMeter(name: "Other Models", percent: api, root: root, now: now)
    }

    private static func periodMeter(name: String, percent: Double, root: [String: Any], now: Date) -> QuotaMeter {
        let start = parseTimestamp(root["billingCycleStart"])
        let end = parseTimestamp(root["billingCycleEnd"])
        let secondsRemaining = end.map { max(0, $0.timeIntervalSince(now)) }
        let pace: PaceResult? = {
            guard let start, let end else { return PaceResult(ratio: nil, label: "Pace n/a", isEarly: false, daysToExhaustion: nil) }
            return PaceCalculator.pace(percentUsed: percent, periodStart: start, periodEnd: end, now: now)
        }()
        return QuotaMeter(
            name: name,
            percentUsed: percent,
            secondsRemaining: secondsRemaining,
            pace: pace,
            isUnavailable: false,
            periodStart: start,
            periodEnd: end
        )
    }

    public static func grokBot(from data: Data, now: Date = Date()) throws -> QuotaMeter {
        let root = try decodeObject(data)
        let pooled = boolValue(root["usesPooledEnterpriseAllowance"]) ?? false
        let includedLimitZero = boolValue(root["includedLimitZero"]) ?? false
        let hasNonZero = boolValue(root["hasNonZeroIncludedLimit"]) ?? true
        let usage = doubleValue(root["usagePercent"])
        let eligible = usage != nil && !pooled && !includedLimitZero && hasNonZero

        guard eligible, let usage else {
            return QuotaMeter(name: "Grok Bot", isUnavailable: true)
        }

        let start = parseTimestamp(root["currentPeriodStart"])
        let end = parseTimestamp(root["nextResetTimestampUtc"])
        let secondsRemaining = end.map { max(0, $0.timeIntervalSince(now)) }
        let pace: PaceResult?
        if let start, let end {
            pace = PaceCalculator.pace(percentUsed: usage, periodStart: start, periodEnd: end, now: now)
        } else {
            pace = PaceResult(ratio: nil, label: "Pace n/a", isEarly: false, daysToExhaustion: nil)
        }
        return QuotaMeter(
            name: "Grok Bot",
            percentUsed: usage,
            secondsRemaining: secondsRemaining,
            pace: pace,
            isUnavailable: false,
            periodStart: start,
            periodEnd: end
        )
    }

    // MARK: - Helpers

    private static func decodeObject(_ data: Data) throws -> [String: Any] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QuotaParseError.invalidJSON
        }
        return obj
    }

    private static func doubleValue(_ raw: Any?) -> Double? {
        switch raw {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s)
        default: return nil
        }
    }

    private static func boolValue(_ raw: Any?) -> Bool? {
        switch raw {
        case let b as Bool: return b
        case let n as NSNumber: return n.boolValue
        default: return nil
        }
    }

    /// Accepts unix ms/seconds (number or digit string) or ISO-8601.
    public static func parseTimestamp(_ raw: Any?) -> Date? {
        guard let raw else { return nil }
        if let n = raw as? NSNumber {
            return dateFromEpoch(n.doubleValue)
        }
        if let i = raw as? Int {
            return dateFromEpoch(Double(i))
        }
        if let d = raw as? Double {
            return dateFromEpoch(d)
        }
        guard let s = raw as? String else { return nil }
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let asDouble = Double(trimmed), trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "-" }) {
            return dateFromEpoch(asDouble)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: trimmed) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: trimmed) { return d }
        if trimmed.hasSuffix("Z") {
            let alt = String(trimmed.dropLast()) + "+00:00"
            if let d = ISO8601DateFormatter().date(from: alt) { return d }
        }
        return nil
    }

    private static func dateFromEpoch(_ value: Double) -> Date {
        // ms vs seconds heuristic (matches PoC)
        let seconds = value > 1e12 ? value / 1000.0 : value
        return Date(timeIntervalSince1970: seconds)
    }
}
