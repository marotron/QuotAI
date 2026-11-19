import Foundation

/// Why a closed 5h→7d sample could not compute an implied weekly percent.
public enum CodexFiveHourWeeklyRatioIncompleteReason: String, Codable, Sendable, Equatable {
    case weeklyResetMidPeriod
    case missingUsage
    case peakZero
}

/// One permanently stored closed short-window period.
public struct CodexFiveHourWeeklyRatioRecord: Equatable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var closedAt: Date
    public var accountID: String?
    public var peak5h: Double
    public var weeklyStart: Double?
    public var weeklyEnd: Double?
    public var weeklyDelta: Double?
    public var impliedWeeklyPctForFull5h: Double?
    public var shortResetsAt: Date?
    public var longResetsAt: Date?
    /// Short-window duration at close (seconds). Nil on older JSON → chart falls back to 5h.
    public var shortDurationSeconds: TimeInterval?
    public var sampleComplete: Bool
    public var incompleteReason: CodexFiveHourWeeklyRatioIncompleteReason?

    public init(
        id: UUID = UUID(),
        closedAt: Date,
        accountID: String?,
        peak5h: Double,
        weeklyStart: Double?,
        weeklyEnd: Double?,
        weeklyDelta: Double?,
        impliedWeeklyPctForFull5h: Double?,
        shortResetsAt: Date?,
        longResetsAt: Date?,
        shortDurationSeconds: TimeInterval? = nil,
        sampleComplete: Bool,
        incompleteReason: CodexFiveHourWeeklyRatioIncompleteReason?
    ) {
        self.id = id
        self.closedAt = closedAt
        self.accountID = accountID
        self.peak5h = peak5h
        self.weeklyStart = weeklyStart
        self.weeklyEnd = weeklyEnd
        self.weeklyDelta = weeklyDelta
        self.impliedWeeklyPctForFull5h = impliedWeeklyPctForFull5h
        self.shortResetsAt = shortResetsAt
        self.longResetsAt = longResetsAt
        self.shortDurationSeconds = shortDurationSeconds
        self.sampleComplete = sampleComplete
        self.incompleteReason = incompleteReason
    }
}

/// Maps a closed ≈5h slice onto the live Codex ≈7d elapsed-% axis for chart bands.
public enum CodexFiveHourWeeklyRatioChartSpan {
    public static let defaultShortDuration: TimeInterval = CodexFiveHourWeeklyRatioWindows.shortTarget

    /// Elapsed-% span on `[periodStart, periodEnd]`, or nil when unmappable / fully outside.
    public static func elapsedPercentSpan(
        record: CodexFiveHourWeeklyRatioRecord,
        periodStart: Date,
        periodEnd: Date
    ) -> (lo: Double, hi: Double)? {
        guard let shortEnd = record.shortResetsAt else { return nil }
        let shortDuration = record.shortDurationSeconds ?? defaultShortDuration
        guard shortDuration > 0, shortDuration.isFinite else { return nil }
        let shortStart = shortEnd.addingTimeInterval(-shortDuration)
        let periodDuration = periodEnd.timeIntervalSince(periodStart)
        guard periodDuration > 0 else { return nil }
        if shortEnd <= periodStart || shortStart >= periodEnd { return nil }
        guard let lo = CursorDiscrepancyElapsed.percent(
            at: shortStart,
            periodStart: periodStart,
            periodEnd: periodEnd
        ),
        let hi = CursorDiscrepancyElapsed.percent(
            at: shortEnd,
            periodStart: periodStart,
            periodEnd: periodEnd
        ) else { return nil }
        return (min(lo, hi), max(lo, hi))
    }
}

/// Picks the ≈5h and ≈7d windows by duration, never by primary/secondary slot.
public enum CodexFiveHourWeeklyRatioWindows {
    public static let shortTarget: TimeInterval = 5 * 3600
    public static let longTarget: TimeInterval = 7 * 86400
    /// Relative tolerance around each target duration.
    public static let durationTolerance: Double = 0.25

    public static func selectPair(
        from windows: [CodexQuotaWindow]
    ) -> (short: CodexQuotaWindow, long: CodexQuotaWindow)? {
        let timed = windows.compactMap { window -> (CodexQuotaWindow, TimeInterval)? in
            guard let duration = window.duration, duration > 0, duration.isFinite else { return nil }
            return (window, duration)
        }
        guard let short = nearest(to: shortTarget, in: timed),
              let long = nearest(to: longTarget, in: timed.filter { $0.0.id != short.0.id }),
              short.1 < long.1
        else { return nil }
        return (short.0, long.0)
    }

    private static func nearest(
        to target: TimeInterval,
        in candidates: [(CodexQuotaWindow, TimeInterval)]
    ) -> (CodexQuotaWindow, TimeInterval)? {
        guard let best = candidates.min(by: { abs($0.1 - target) < abs($1.1 - target) }) else {
            return nil
        }
        guard abs(best.1 - target) / target <= durationTolerance else { return nil }
        return best
    }
}

/// In-memory observer: opens only after short-window usage > 0 (Codex starts the 5h window on first use),
/// closes when that window's `resetsAt` changes. Idle floating `resetsAt` values are ignored.
public final class CodexFiveHourWeeklyRatioTracker: @unchecked Sendable {
    private struct OpenPeriod {
        var accountID: String?
        var shortResetsAt: Date
        var shortDurationSeconds: TimeInterval?
        var longResetsAt: Date?
        var peak5h: Double
        var weeklyStart: Double?
        var weeklyEnd: Double?
        var weeklyResetChanged: Bool
        var missingUsage: Bool
    }

    private let lock = NSLock()
    private var open: OpenPeriod?

    public init() {}

    /// Returns a closed record when an opened short window rolls; otherwise updates or stays idle.
    @discardableResult
    public func observe(
        windows: [CodexQuotaWindow],
        accountID: String?,
        at stamp: Date
    ) -> CodexFiveHourWeeklyRatioRecord? {
        lock.lock()
        defer { lock.unlock() }

        guard let pair = CodexFiveHourWeeklyRatioWindows.selectPair(from: windows),
              let shortReset = pair.short.resetsAt
        else { return nil }

        if let current = open, current.accountID != accountID {
            open = nil
        }

        if let current = open, current.shortResetsAt != shortReset {
            // Only a period that actually saw usage is worth storing.
            let record = current.peak5h > 0 ? Self.close(current, at: stamp) : nil
            open = Self.startIfActive(pair: pair, accountID: accountID)
            return record
        }

        if open == nil {
            open = Self.startIfActive(pair: pair, accountID: accountID)
            return nil
        }

        applyObservation(pair: pair)
        return nil
    }

    /// Drop the in-memory open period without writing a record (e.g. tracking turned off).
    public func abandonOpenPeriod() {
        lock.lock()
        defer { lock.unlock() }
        open = nil
    }

    private func applyObservation(pair: (short: CodexQuotaWindow, long: CodexQuotaWindow)) {
        guard var current = open else { return }
        if let duration = pair.short.duration, duration > 0, duration.isFinite {
            current.shortDurationSeconds = duration
        }
        if let used = pair.short.usedPercent, used.isFinite {
            current.peak5h = max(current.peak5h, used)
        } else {
            current.missingUsage = true
        }
        if let weekly = pair.long.usedPercent, weekly.isFinite {
            if current.weeklyStart == nil { current.weeklyStart = weekly }
            current.weeklyEnd = weekly
        } else {
            current.missingUsage = true
        }
        if let longReset = pair.long.resetsAt {
            if let started = current.longResetsAt, started != longReset {
                current.weeklyResetChanged = true
            } else if current.longResetsAt == nil {
                current.longResetsAt = longReset
            }
        }
        open = current
    }

    /// Codex does not start the ≈5h window until first usage; unused polls often show a drifting `resetsAt`.
    private static func startIfActive(
        pair: (short: CodexQuotaWindow, long: CodexQuotaWindow),
        accountID: String?
    ) -> OpenPeriod? {
        guard let shortReset = pair.short.resetsAt,
              let shortUsed = pair.short.usedPercent,
              shortUsed.isFinite,
              shortUsed > 0
        else { return nil }
        var missing = false
        let weekly: Double?
        if let used = pair.long.usedPercent, used.isFinite {
            weekly = used
        } else {
            weekly = nil
            missing = true
        }
        let shortDuration: TimeInterval?
        if let duration = pair.short.duration, duration > 0, duration.isFinite {
            shortDuration = duration
        } else {
            shortDuration = nil
        }
        return OpenPeriod(
            accountID: accountID,
            shortResetsAt: shortReset,
            shortDurationSeconds: shortDuration,
            longResetsAt: pair.long.resetsAt,
            peak5h: shortUsed,
            weeklyStart: weekly,
            weeklyEnd: weekly,
            weeklyResetChanged: false,
            missingUsage: missing
        )
    }

    private static func close(_ open: OpenPeriod, at stamp: Date) -> CodexFiveHourWeeklyRatioRecord {
        let weeklyStart = open.weeklyStart
        let weeklyEnd = open.weeklyEnd
        let weeklyDelta: Double?
        if let weeklyStart, let weeklyEnd {
            weeklyDelta = weeklyEnd - weeklyStart
        } else {
            weeklyDelta = nil
        }

        let reason: CodexFiveHourWeeklyRatioIncompleteReason?
        let implied: Double?
        if open.weeklyResetChanged {
            reason = .weeklyResetMidPeriod
            implied = nil
        } else if open.missingUsage || weeklyStart == nil || weeklyEnd == nil {
            reason = .missingUsage
            implied = nil
        } else if open.peak5h <= 0 {
            reason = .peakZero
            implied = nil
        } else if let weeklyDelta {
            reason = nil
            implied = weeklyDelta / (open.peak5h / 100)
        } else {
            reason = .missingUsage
            implied = nil
        }

        return CodexFiveHourWeeklyRatioRecord(
            closedAt: stamp,
            accountID: open.accountID,
            peak5h: open.peak5h,
            weeklyStart: weeklyStart,
            weeklyEnd: weeklyEnd,
            weeklyDelta: weeklyDelta,
            impliedWeeklyPctForFull5h: implied,
            shortResetsAt: open.shortResetsAt,
            longResetsAt: open.longResetsAt,
            shortDurationSeconds: open.shortDurationSeconds,
            sampleComplete: reason == nil,
            incompleteReason: reason
        )
    }
}

/// JSON history of closed 5h→7d ratio records. Genuine samples are append-only;
/// idle `peakZero` / peak ≤ 0 artifacts may be purged once on load.
public final class CodexFiveHourWeeklyRatioStore: @unchecked Sendable {
    public static let defaultFileName = "codex-5h-weekly-ratio.json"

    public static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("dev.marotron.QuotAI", isDirectory: true)
            .appendingPathComponent(defaultFileName)
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var stored: [CodexFiveHourWeeklyRatioRecord]

    public init(fileURL: URL = CodexFiveHourWeeklyRatioStore.defaultFileURL) {
        self.fileURL = fileURL
        self.stored = Self.load(from: fileURL)
    }

    public var records: [CodexFiveHourWeeklyRatioRecord] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    public func append(_ record: CodexFiveHourWeeklyRatioRecord) throws {
        lock.lock()
        defer { lock.unlock() }
        stored.append(record)
        try Self.save(stored, to: fileURL)
    }

    /// Removes idle false-close artifacts (`peakZero` or peak ≤ 0). Keeps other incompletes.
    @discardableResult
    public func purgePeakZeroArtifacts() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let kept = stored.filter { !Self.isPeakZeroArtifact($0) }
        let removed = stored.count - kept.count
        guard removed > 0 else { return 0 }
        stored = kept
        try Self.save(stored, to: fileURL)
        return removed
    }

    public static func isPeakZeroArtifact(_ record: CodexFiveHourWeeklyRatioRecord) -> Bool {
        record.incompleteReason == .peakZero || record.peak5h <= 0
    }

    private struct DiskPayload: Codable {
        var records: [CodexFiveHourWeeklyRatioRecord]
    }

    private static func load(from url: URL) -> [CodexFiveHourWeeklyRatioRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let payload = try? JSONDecoder().decode(DiskPayload.self, from: data) else { return [] }
        return payload.records
    }

    private static func save(_ records: [CodexFiveHourWeeklyRatioRecord], to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(DiskPayload(records: records))
        try data.write(to: url, options: .atomic)
    }
}
