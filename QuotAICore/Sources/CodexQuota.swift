import Foundation

public struct CodexQuotaWindow: Equatable, Identifiable, Sendable {
    public var id: String
    public var bucketName: String
    public var slot: String
    public var usedPercent: Double?
    public var duration: TimeInterval?
    public var resetsAt: Date?

    public var durationLabel: String {
        guard let duration else { return slot.capitalized }
        if duration.truncatingRemainder(dividingBy: 86400) == 0 { return "\(Int(duration / 86400))d" }
        if duration.truncatingRemainder(dividingBy: 3600) == 0 { return "\(Int(duration / 3600))h" }
        return "\(Int(duration / 60))m"
    }

    public var title: String { "\(bucketName) · \(durationLabel)" }
}

public struct CodexQuotaSnapshot: Equatable, Sendable {
    public var accountID: String?
    public var ordinaryUsageAllowed: Bool?
    public var windows: [CodexQuotaWindow]

    public static func parse(_ data: Data, expectedAccount: String) throws -> Self {
        struct Window: Decodable {
            var used_percent: Double?
            var limit_window_seconds: Double?
            var reset_at: Double?
        }
        struct Limit: Decodable {
            var allowed: Bool?
            var primary_window: Window?
            var secondary_window: Window?
        }
        struct Additional: Decodable {
            var metered_feature: String
            var limit_name: String?
            var rate_limit: Limit?
        }
        struct Payload: Decodable {
            var account_id: String?
            var rate_limit: Limit?
            var additional_rate_limits: [Additional]?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        if let account = payload.account_id, account != expectedAccount { throw ParseError.accountMismatch }
        var windows: [CodexQuotaWindow] = []
        func append(_ limit: Limit?, bucket: String, title: String) {
            for (slot, raw) in [("primary", limit?.primary_window), ("secondary", limit?.secondary_window)] {
                guard let raw else { continue }
                let used = raw.used_percent.flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
                let duration = raw.limit_window_seconds.flatMap { $0.isFinite && $0 >= 60 && $0 <= 315360000 ? $0 : nil }
                let end = raw.reset_at.flatMap { $0.isFinite && $0 > 0 && $0 < 253402300800 ? Date(timeIntervalSince1970: $0) : nil }
                windows.append(CodexQuotaWindow(id: "\(bucket).\(slot)", bucketName: title,
                    slot: slot, usedPercent: used, duration: duration, resetsAt: end))
            }
        }
        append(payload.rate_limit, bucket: "codex", title: "Codex")
        for additional in payload.additional_rate_limits ?? [] {
            guard !additional.metered_feature.isEmpty else { throw ParseError.invalidBucket }
            append(additional.rate_limit, bucket: additional.metered_feature,
                title: additional.limit_name.flatMap { $0.isEmpty ? nil : $0 } ?? additional.metered_feature)
        }
        guard Set(windows.map(\.id)).count == windows.count else { throw ParseError.invalidBucket }
        return Self(accountID: payload.account_id, ordinaryUsageAllowed: payload.rate_limit?.allowed, windows: windows)
    }

    public enum ParseError: Error { case accountMismatch, invalidBucket }
}

public struct CodexRefreshRule: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var percent: Int
    public var minutes: Int

    public init(enabled: Bool = false, percent: Int = 90, minutes: Int = 1) {
        self.enabled = enabled
        self.percent = min(max(percent, 0), 99)
        self.minutes = min(max(minutes, 1), 60)
    }

    public var normalized: Self { Self(enabled: enabled, percent: percent, minutes: minutes) }
}

/// One request serves every Codex bucket/window. Active triggers latch until that window resets.
public struct CodexRefreshState: Codable, Equatable, Sendable {
    public var activeEnds: [String: Date] = [:]
    public init() {}

    public mutating func update(windows: [CodexQuotaWindow], rules: [String: CodexRefreshRule],
                                fetchedAt: Date?, now: Date) {
        activeEnds = activeEnds.filter { rules[$0.key]?.enabled == true && $0.value > now }
        for window in windows {
            if let end = window.resetsAt, let active = activeEnds[window.id], end != active {
                activeEnds.removeValue(forKey: window.id)
            }
            guard let rule = rules[window.id]?.normalized, rule.enabled,
                  let fetchedAt, now.timeIntervalSince(fetchedAt) >= 0,
                  now.timeIntervalSince(fetchedAt) <= 3600,
                  let used = window.usedPercent, used >= Double(rule.percent),
                  let reset = window.resetsAt, reset > now else { continue }
            activeEnds[window.id] = reset
        }
    }

    public func interval(normal: TimeInterval, rules: [String: CodexRefreshRule], now: Date) -> TimeInterval {
        activeEnds.reduce(normal) { interval, entry in
            guard entry.value > now, let rule = rules[entry.key]?.normalized, rule.enabled else { return interval }
            return min(interval, TimeInterval(rule.minutes * 60))
        }
    }
}
