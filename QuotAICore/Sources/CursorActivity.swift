import Foundation

/// Cursor's two quota meters that agent turns can consume.
public enum CursorMeterClassification: String, Codable, CaseIterable, Equatable, Sendable {
    case cursorModels
    case otherModels
}

/// A local Cursor Agent Host turn, keyed by the generation UUID written by Cursor.
public struct CursorAgentTurn: Codable, Equatable, Sendable, Identifiable {
    public var timestamp: Date
    public var generationUUID: String
    public var meter: CursorMeterClassification
    /// Real model IDs for composer/grok/third-party; Cursor's `default`/`auto` runtime stores `"auto"`.
    public var modelID: String?
    /// Latest Agent Host activity timestamp for this UUID; nil means unknown (point-in-time at `timestamp`).
    public var endedAt: Date?

    public var id: String { generationUUID }

    public init(
        timestamp: Date,
        generationUUID: String,
        meter: CursorMeterClassification,
        modelID: String?,
        endedAt: Date? = nil
    ) {
        self.timestamp = timestamp
        self.generationUUID = generationUUID
        self.meter = meter
        self.modelID = modelID
        self.endedAt = endedAt
    }
}

/// Pure parser for the selected-runtime lines in Cursor Agent Host logs.
public enum CursorActivityParser {
    private static let marker = "Selected Agent Host turn runtime "

    /// Spending-pool classification from a Cursor model id (logs or usage CSV).
    /// Cursor Models: `default` / `auto`, `composer*`, agent `grok*` / `cursor-grok*`
    /// (not `grok-bot*`). Everything else → Other Models.
    public static func classify(modelID: String) -> (meter: CursorMeterClassification, storedModelID: String?) {
        let lowered = modelID.lowercased()
        if lowered == "default" || lowered == "auto" {
            return (.cursorModels, "auto")
        }
        if lowered.hasPrefix("composer")
            || lowered.hasPrefix("cursor-grok")
            || (lowered.hasPrefix("grok") && !lowered.hasPrefix("grok-bot"))
        {
            return (.cursorModels, modelID)
        }
        return (.otherModels, modelID)
    }

    /// Returns turns mentioned in this chunk, extending activity for starts retained from earlier reads.
    public static func parse(log: String, knownTurns: [CursorAgentTurn] = []) -> [CursorAgentTurn] {
        let lines = log.components(separatedBy: "\n")
        var turnsByUUID: [String: CursorAgentTurn] = [:]
        for turn in knownTurns {
            turnsByUUID[turn.generationUUID.lowercased()] = turn
        }
        var order: [String] = []
        var mentioned = Set<String>()

        for line in lines {
            guard let turn = parse(line: line) else { continue }
            let key = turn.generationUUID.lowercased()
            if turnsByUUID[key] == nil {
                turnsByUUID[key] = turn
            }
            if mentioned.insert(key).inserted { order.append(key) }
        }

        guard !turnsByUUID.isEmpty else { return [] }

        // O(lines): extract UUID-shaped tokens per line and intersect with known starts.
        // Avoids O(lines × turns) substring scans that stall full-log backfills (~45MB).
        var latestActivity: [String: Date] = [:]
        for line in lines {
            guard let timestamp = parseLineTimestamp(line) else { continue }
            for uuid in uuidTokens(in: line) {
                let key = uuid.lowercased()
                guard turnsByUUID[key] != nil else { continue }
                if mentioned.insert(key).inserted { order.append(key) }
                if let prior = latestActivity[key] {
                    if timestamp > prior { latestActivity[key] = timestamp }
                } else {
                    latestActivity[key] = timestamp
                }
            }
        }

        return order.compactMap { key in
            guard var turn = turnsByUUID[key] else { return nil }
            if let activity = latestActivity[key], activity > (turn.endedAt ?? turn.timestamp) {
                turn.endedAt = activity
            }
            return turn
        }
    }

    private static func parse(line: String) -> CursorAgentTurn? {
        guard line.contains(marker),
              let markerRange = line.range(of: marker),
              let timestamp = parseTimestamp(String(line[..<markerRange.lowerBound]))
        else {
            return nil
        }

        let payloadText = String(line[markerRange.upperBound...])
        guard let data = payloadText.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let generationUUID = payload["generationUUID"] as? String,
              UUID(uuidString: generationUUID) != nil,
              let modelID = payload["modelId"] as? String,
              !modelID.isEmpty
        else {
            return nil
        }

        let classified = classify(modelID: modelID)
        return CursorAgentTurn(
            timestamp: timestamp,
            generationUUID: generationUUID,
            meter: classified.meter,
            modelID: classified.storedModelID
        )
    }

    private static func parseLineTimestamp(_ line: String) -> Date? {
        guard line.count >= 23 else { return nil }
        return parseTimestamp(String(line.prefix(23)))
    }

    private static let uuidTokenRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        )
    }()

    private static func uuidTokens(in line: String) -> [String] {
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        return uuidTokenRegex.matches(in: line, options: [], range: nsRange).compactMap { match in
            Range(match.range, in: line).map { String(line[$0]) }
        }
    }

    private static let timestampLock = NSLock()
    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private static func parseTimestamp(_ prefix: String) -> Date? {
        let raw = prefix.trimmingCharacters(in: .whitespaces)
        guard raw.count >= 23 else { return nil }
        let dateText = String(raw.prefix(23))
        timestampLock.lock()
        defer { timestampLock.unlock() }
        return timestampFormatter.date(from: dateText)
    }
}

/// A sampled value for the two Cursor billing-cycle meters.
public struct CursorMeterSnapshot: Codable, Equatable, Sendable {
    public var timestamp: Date
    public var cursorModelsPercentUsed: Double?
    public var otherModelsPercentUsed: Double?

    public init(
        timestamp: Date,
        cursorModelsPercentUsed: Double?,
        otherModelsPercentUsed: Double?
    ) {
        self.timestamp = timestamp
        self.cursorModelsPercentUsed = cursorModelsPercentUsed
        self.otherModelsPercentUsed = otherModelsPercentUsed
    }

    public func percentUsed(for meter: CursorMeterClassification) -> Double? {
        switch meter {
        case .cursorModels: return cursorModelsPercentUsed
        case .otherModels: return otherModelsPercentUsed
        }
    }
}

public struct CursorDiscrepancyEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Equatable, Sendable, CaseIterable {
        case unbilledActivity
        case unattributedQuotaChange
    }

    public var kind: Kind
    public var meter: CursorMeterClassification
    public var timestamp: Date
    public var generationUUIDs: [String]
    public var modelIDs: [String]

    /// Stable across reconciliation passes, suitable for notification de-duplication.
    public var notificationSignature: String {
        [
            kind.rawValue,
            meter.rawValue,
            String(timestamp.timeIntervalSince1970),
            generationUUIDs.sorted().joined(separator: ","),
            modelIDs.sorted().joined(separator: ","),
        ].joined(separator: "|")
    }

    public var id: String { notificationSignature }

    public init(
        kind: Kind,
        meter: CursorMeterClassification,
        timestamp: Date,
        generationUUIDs: [String] = [],
        modelIDs: [String] = []
    ) {
        self.kind = kind
        self.meter = meter
        self.timestamp = timestamp
        self.generationUUIDs = generationUUIDs
        self.modelIDs = modelIDs
    }

    /// Strip / tip label: local model ids, with Cursor Models defaulting to `auto`.
    public var displayModelLabel: String {
        if !modelIDs.isEmpty { return modelIDs.joined(separator: ", ") }
        if meter == .cursorModels { return "auto" }
        return "—"
    }
}

/// Linear elapsed % of the billing period for discrepancy chart marks (no pace ε floor).
public enum CursorDiscrepancyElapsed {
    public static func percent(
        at timestamp: Date,
        periodStart: Date,
        periodEnd: Date
    ) -> Double? {
        let duration = periodEnd.timeIntervalSince(periodStart)
        guard duration > 0 else { return nil }
        let raw = ((timestamp.timeIntervalSince(periodStart) / duration) * 100)
        return min(max(raw, 0), 100)
    }
}

public struct CursorDiscrepancyCluster: Equatable, Sendable, Identifiable {
    public var elapsedLo: Double
    public var elapsedHi: Double
    public var centerElapsed: Double
    public var events: [CursorDiscrepancyEvent]

    public var id: String {
        let first = events.first?.notificationSignature ?? "empty"
        let last = events.last?.notificationSignature ?? first
        return "\(elapsedLo)|\(elapsedHi)|\(first)|\(last)"
    }

    public init(
        elapsedLo: Double,
        elapsedHi: Double,
        centerElapsed: Double,
        events: [CursorDiscrepancyEvent]
    ) {
        self.elapsedLo = elapsedLo
        self.elapsedHi = elapsedHi
        self.centerElapsed = centerElapsed
        self.events = events
    }
}

/// Greedy merge of discrepancy events along the elapsed-% axis.
public enum CursorDiscrepancyClusterer {
    public static let defaultGapThresholdElapsedPercent: Double = 2.0

    public static func cluster(
        events: [CursorDiscrepancyEvent],
        periodStart: Date,
        periodEnd: Date,
        gapThresholdElapsedPercent: Double = defaultGapThresholdElapsedPercent
    ) -> [CursorDiscrepancyCluster] {
        let positioned: [(event: CursorDiscrepancyEvent, elapsed: Double)] = events
            .compactMap { event in
                guard let elapsed = CursorDiscrepancyElapsed.percent(
                    at: event.timestamp,
                    periodStart: periodStart,
                    periodEnd: periodEnd
                ) else {
                    return nil
                }
                return (event, elapsed)
            }
            .sorted { lhs, rhs in
                if lhs.elapsed != rhs.elapsed { return lhs.elapsed < rhs.elapsed }
                return lhs.event.timestamp < rhs.event.timestamp
            }

        guard !positioned.isEmpty else { return [] }

        var clusters: [CursorDiscrepancyCluster] = []
        var currentEvents: [CursorDiscrepancyEvent] = [positioned[0].event]
        var currentLo = positioned[0].elapsed
        var currentHi = positioned[0].elapsed

        for item in positioned.dropFirst() {
            if item.elapsed - currentHi <= gapThresholdElapsedPercent {
                currentEvents.append(item.event)
                currentHi = item.elapsed
            } else {
                clusters.append(makeCluster(events: currentEvents, lo: currentLo, hi: currentHi))
                currentEvents = [item.event]
                currentLo = item.elapsed
                currentHi = item.elapsed
            }
        }
        clusters.append(makeCluster(events: currentEvents, lo: currentLo, hi: currentHi))
        return clusters
    }

    private static func makeCluster(
        events: [CursorDiscrepancyEvent],
        lo: Double,
        hi: Double
    ) -> CursorDiscrepancyCluster {
        CursorDiscrepancyCluster(
            elapsedLo: lo,
            elapsedHi: hi,
            centerElapsed: (lo + hi) / 2,
            events: events
        )
    }
}

/// Matches local turns to subsequent quota increases inside the allowed lag window.
public enum CursorDiscrepancyReconciler {
    public static let graceWindow: TimeInterval = 5 * 60
    /// Walk back through flat intermediate snaps this far when sizing an increase's window.
    public static let plateauLookback: TimeInterval = 15 * 60
    /// Meter updates lag billed requests; a same-meter turn whose active interval overlaps
    /// `[bump − lookback, bump + grace]` still counts as local activity for unattributed checks.
    public static let unattributedLookback: TimeInterval = 20 * 60

    public static func reconcile(
        turns: [CursorAgentTurn],
        snapshots: [CursorMeterSnapshot],
        now: Date = Date(),
        graceWindow: TimeInterval = graceWindow,
        plateauLookback: TimeInterval = plateauLookback,
        unattributedLookback: TimeInterval = unattributedLookback
    ) -> [CursorDiscrepancyEvent] {
        let orderedTurns = turns.sorted { $0.timestamp < $1.timestamp }
        let orderedSnapshots = snapshots.sorted { $0.timestamp < $1.timestamp }
        let increases = meterIncreases(from: orderedSnapshots)
        var matchedTurnIDs = Set<String>()

        for increase in increases {
            let window = attributionWindow(
                for: increase,
                snapshots: orderedSnapshots,
                graceWindow: graceWindow,
                plateauLookback: plateauLookback
            )
            for turn in orderedTurns
                where turn.meter == increase.meter
                    && !matchedTurnIDs.contains(turn.generationUUID)
                    && turn.timestamp > window.start
                    && turn.timestamp <= window.end
            {
                matchedTurnIDs.insert(turn.generationUUID)
            }
        }

        var events: [CursorDiscrepancyEvent] = []
        for turn in orderedTurns
            where !matchedTurnIDs.contains(turn.generationUUID)
                && orderedSnapshots.contains(where: { $0.timestamp <= turn.timestamp })
                && now > turn.timestamp.addingTimeInterval(graceWindow)
        {
            events.append(
                CursorDiscrepancyEvent(
                    kind: .unbilledActivity,
                    meter: turn.meter,
                    timestamp: turn.timestamp,
                    generationUUIDs: [turn.generationUUID],
                    modelIDs: turn.modelID.map { [$0] } ?? []
                )
            )
        }

        for increase in increases
            where now > increase.timestamp.addingTimeInterval(graceWindow)
        {
            let window = attributionWindow(
                for: increase,
                snapshots: orderedSnapshots,
                graceWindow: graceWindow,
                plateauLookback: plateauLookback
            )
            // "Without local activity" — overlapping same-meter turns (matched or not) explain the bump.
            let explainStart = min(window.start, increase.timestamp.addingTimeInterval(-unattributedLookback))
            let hasNearbyTurn = orderedTurns.contains {
                $0.meter == increase.meter
                    && $0.timestamp <= window.end
                    && ($0.endedAt ?? $0.timestamp) > explainStart
            }
            guard !hasNearbyTurn else { continue }
            events.append(
                CursorDiscrepancyEvent(
                    kind: .unattributedQuotaChange,
                    meter: increase.meter,
                    timestamp: increase.timestamp
                )
            )
        }
        return events.sorted { $0.timestamp < $1.timestamp }
    }

    private struct MeterIncrease {
        var id: String
        var meter: CursorMeterClassification
        var timestamp: Date
        var previousSnapshotTimestamp: Date
        var previousPercentUsed: Double
    }

    private struct AttributionWindow {
        var start: Date
        var end: Date
    }

    private static func attributionWindow(
        for increase: MeterIncrease,
        snapshots: [CursorMeterSnapshot],
        graceWindow: TimeInterval,
        plateauLookback: TimeInterval
    ) -> AttributionWindow {
        let plateauStart = plateauStartTimestamp(
            for: increase,
            snapshots: snapshots,
            lookback: plateauLookback
        )
        let start = min(plateauStart, increase.timestamp.addingTimeInterval(-graceWindow))
        let end = increase.timestamp.addingTimeInterval(graceWindow)
        return AttributionWindow(start: start, end: end)
    }

    /// Immediate previous snap, then walk back through equal readings within `lookback`.
    private static func plateauStartTimestamp(
        for increase: MeterIncrease,
        snapshots: [CursorMeterSnapshot],
        lookback: TimeInterval
    ) -> Date {
        let limit = increase.previousSnapshotTimestamp.addingTimeInterval(-lookback)
        var plateauStart = increase.previousSnapshotTimestamp
        let baseline = increase.previousPercentUsed
        for snapshot in snapshots.reversed() {
            guard snapshot.timestamp < increase.previousSnapshotTimestamp else { continue }
            guard snapshot.timestamp >= limit else { break }
            guard let value = snapshot.percentUsed(for: increase.meter),
                  value == baseline
            else {
                break
            }
            plateauStart = snapshot.timestamp
        }
        return plateauStart
    }

    private static func meterIncreases(from snapshots: [CursorMeterSnapshot]) -> [MeterIncrease] {
        CursorMeterClassification.allCases.flatMap { meter in
            zip(snapshots, snapshots.dropFirst()).compactMap { previous, current in
                guard let prior = previous.percentUsed(for: meter),
                      let next = current.percentUsed(for: meter),
                      next > prior
                else {
                    return nil
                }
                return MeterIncrease(
                    id: "\(meter.rawValue)|\(current.timestamp.timeIntervalSince1970)",
                    meter: meter,
                    timestamp: current.timestamp,
                    previousSnapshotTimestamp: previous.timestamp,
                    previousPercentUsed: prior
                )
            }
        }
    }
}

/// Builds detector meter snapshots from pace-history samples for the current billing period.
/// Joins `.cursor` / `.other` readings that share a timestamp; ignores `.grok`.
public enum CursorDiscrepancySnapshotBackfill {
    public static func snapshots(
        from samples: [PaceHistorySample],
        periodStart: Date
    ) -> [CursorMeterSnapshot] {
        var byTimestamp: [Date: (cursor: Double?, other: Double?)] = [:]
        for sample in samples where sample.periodStart == periodStart {
            switch sample.meterId {
            case .cursor:
                var entry = byTimestamp[sample.timestamp] ?? (nil, nil)
                entry.cursor = sample.usedPct
                byTimestamp[sample.timestamp] = entry
            case .other:
                var entry = byTimestamp[sample.timestamp] ?? (nil, nil)
                entry.other = sample.usedPct
                byTimestamp[sample.timestamp] = entry
            case .grok:
                continue
            }
        }
        return byTimestamp.keys.sorted().map { timestamp in
            let entry = byTimestamp[timestamp]!
            return CursorMeterSnapshot(
                timestamp: timestamp,
                cursorModelsPercentUsed: entry.cursor,
                otherModelsPercentUsed: entry.other
            )
        }
    }
}

/// JSON-backed current billing-period state. The store deliberately has no cross-period history.
public final class CursorActivityStore: @unchecked Sendable {
    public static let defaultFileName = "cursor-activity.json"

    public static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("dev.marotron.QuotAI", isDirectory: true)
            .appendingPathComponent(defaultFileName)
    }

    public struct State: Equatable, Sendable {
        public var periodStart: Date?
        public var turns: [CursorAgentTurn]
        public var snapshots: [CursorMeterSnapshot]
        public var events: [CursorDiscrepancyEvent]
        /// Absolute paths → last consumed byte offset in each Agent Host log.
        /// Survives relaunches so cold start does not re-parse whole log files.
        public var logByteOffsets: [String: UInt64]
        /// One-shot: historical logs were re-read to fill `endedAt` on retained turns.
        public var didBackfillTurnEndedAt: Bool
        /// Separate from the original backfill: even non-nil ends could go stale between reads.
        public var didBackfillIncrementalTurnActivity: Bool

        public var needsTurnActivityBackfill: Bool {
            !didBackfillIncrementalTurnActivity && !turns.isEmpty
        }

        public init(
            periodStart: Date? = nil,
            turns: [CursorAgentTurn] = [],
            snapshots: [CursorMeterSnapshot] = [],
            events: [CursorDiscrepancyEvent] = [],
            logByteOffsets: [String: UInt64] = [:],
            didBackfillTurnEndedAt: Bool = false,
            didBackfillIncrementalTurnActivity: Bool = false
        ) {
            self.periodStart = periodStart
            self.turns = turns
            self.snapshots = snapshots
            self.events = events
            self.logByteOffsets = logByteOffsets
            self.didBackfillTurnEndedAt = didBackfillTurnEndedAt
            self.didBackfillIncrementalTurnActivity = didBackfillIncrementalTurnActivity
        }

        enum CodingKeys: String, CodingKey {
            case periodStart, turns, snapshots, events, logByteOffsets, didBackfillTurnEndedAt
            case didBackfillIncrementalTurnActivity
        }
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var storedState: State

    public var state: State {
        lock.lock()
        defer { lock.unlock() }
        return storedState
    }

    public init(fileURL: URL = CursorActivityStore.defaultFileURL) {
        self.fileURL = fileURL
        self.storedState = Self.load(from: fileURL)
        if Self.normalizeMeterClassifications(in: &storedState) {
            try? Self.save(storedState, to: fileURL)
        }
    }

    public func replacePeriodIfNeeded(periodStart: Date) throws {
        lock.lock()
        defer { lock.unlock() }
        guard storedState.periodStart != periodStart else { return }
        // Keep log cursors and backfill flags: files are not period-scoped.
        let offsets = storedState.logByteOffsets
        let endedAtBackfill = storedState.didBackfillTurnEndedAt
        let incrementalActivityBackfill = storedState.didBackfillIncrementalTurnActivity
        storedState = State(
            periodStart: periodStart,
            logByteOffsets: offsets,
            didBackfillTurnEndedAt: endedAtBackfill,
            didBackfillIncrementalTurnActivity: incrementalActivityBackfill
        )
        try Self.save(storedState, to: fileURL)
    }

    public func replaceLogByteOffsets(_ offsets: [String: UInt64]) throws {
        lock.lock()
        defer { lock.unlock() }
        guard storedState.logByteOffsets != offsets else { return }
        storedState.logByteOffsets = offsets
        try Self.save(storedState, to: fileURL)
    }

    /// Marks both the original end-time backfill and the repair for stale incremental ends complete.
    public func markTurnEndedAtBackfilled() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !storedState.didBackfillTurnEndedAt || !storedState.didBackfillIncrementalTurnActivity else { return }
        storedState.didBackfillTurnEndedAt = true
        storedState.didBackfillIncrementalTurnActivity = true
        try Self.save(storedState, to: fileURL)
    }

    public func append(turns: [CursorAgentTurn]) throws {
        guard !turns.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var byUUID = Dictionary(uniqueKeysWithValues: storedState.turns.map { ($0.generationUUID, $0) })
        for turn in turns {
            if var existing = byUUID[turn.generationUUID] {
                if let incomingEnd = turn.endedAt,
                   existing.endedAt.map({ incomingEnd > $0 }) ?? true
                {
                    existing.endedAt = incomingEnd
                    byUUID[turn.generationUUID] = existing
                }
            } else {
                byUUID[turn.generationUUID] = turn
            }
        }
        storedState.turns = byUUID.values.sorted { $0.timestamp < $1.timestamp }
        _ = Self.normalizeMeterClassifications(in: &storedState)
        try Self.save(storedState, to: fileURL)
    }

    /// Rewrites turn/event meters from model IDs so pre-fix composer/grok rows match Spending pools.
    @discardableResult
    public func normalizeMeterClassifications() throws -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard Self.normalizeMeterClassifications(in: &storedState) else { return false }
        try Self.save(storedState, to: fileURL)
        return true
    }

    public func append(snapshots: [CursorMeterSnapshot]) throws {
        guard !snapshots.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var knownTimes = Set(storedState.snapshots.map(\.timestamp))
        storedState.snapshots.append(contentsOf: snapshots.filter { knownTimes.insert($0.timestamp).inserted })
        storedState.snapshots.sort { $0.timestamp < $1.timestamp }
        try Self.save(storedState, to: fileURL)
    }

    public func merge(events: [CursorDiscrepancyEvent]) throws {
        guard !events.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var known = Set(storedState.events.map(\.notificationSignature))
        storedState.events.append(contentsOf: events.filter { known.insert($0.notificationSignature).inserted })
        storedState.events.sort { $0.timestamp < $1.timestamp }
        try Self.save(storedState, to: fileURL)
    }

    /// Replaces the reconciled event set so false positives drop when matching rules change.
    public func replace(events: [CursorDiscrepancyEvent]) throws {
        lock.lock()
        defer { lock.unlock() }
        storedState.events = events.sorted { $0.timestamp < $1.timestamp }
        try Self.save(storedState, to: fileURL)
    }

    private static func load(from url: URL) -> State {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(State.self, from: data)
        else {
            return State()
        }
        return payload
    }

    private static func save(_ state: State, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: url, options: .atomic)
    }

    @discardableResult
    private static func normalizeMeterClassifications(in state: inout State) -> Bool {
        var changed = false

        state.turns = state.turns.map { turn in
            let corrected: CursorAgentTurn
            if let modelID = turn.modelID {
                let classified = CursorActivityParser.classify(modelID: modelID)
                corrected = CursorAgentTurn(
                    timestamp: turn.timestamp,
                    generationUUID: turn.generationUUID,
                    meter: classified.meter,
                    modelID: classified.storedModelID,
                    endedAt: turn.endedAt
                )
            } else {
                // Legacy nil modelID means Cursor's `default`/`auto` pool.
                corrected = CursorAgentTurn(
                    timestamp: turn.timestamp,
                    generationUUID: turn.generationUUID,
                    meter: .cursorModels,
                    modelID: "auto",
                    endedAt: turn.endedAt
                )
            }
            if corrected != turn { changed = true }
            return corrected
        }

        state.events = state.events.map { event in
            if event.modelIDs.isEmpty {
                guard event.meter == .cursorModels else { return event }
                changed = true
                return CursorDiscrepancyEvent(
                    kind: event.kind,
                    meter: event.meter,
                    timestamp: event.timestamp,
                    generationUUIDs: event.generationUUIDs,
                    modelIDs: ["auto"]
                )
            }
            let classified = CursorActivityParser.classify(modelID: event.modelIDs[0])
            let modelIDs = event.modelIDs.map { id in
                CursorActivityParser.classify(modelID: id).storedModelID ?? id
            }
            guard classified.meter != event.meter || modelIDs != event.modelIDs else { return event }
            changed = true
            return CursorDiscrepancyEvent(
                kind: event.kind,
                meter: classified.meter,
                timestamp: event.timestamp,
                generationUUIDs: event.generationUUIDs,
                modelIDs: modelIDs
            )
        }

        return changed
    }
}

extension CursorActivityStore.State: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        periodStart = try container.decodeIfPresent(Date.self, forKey: .periodStart)
        turns = try container.decodeIfPresent([CursorAgentTurn].self, forKey: .turns) ?? []
        snapshots = try container.decodeIfPresent([CursorMeterSnapshot].self, forKey: .snapshots) ?? []
        events = try container.decodeIfPresent([CursorDiscrepancyEvent].self, forKey: .events) ?? []
        logByteOffsets = try container.decodeIfPresent([String: UInt64].self, forKey: .logByteOffsets) ?? [:]
        didBackfillTurnEndedAt = try container.decodeIfPresent(Bool.self, forKey: .didBackfillTurnEndedAt) ?? false
        didBackfillIncrementalTurnActivity = try container.decodeIfPresent(
            Bool.self, forKey: .didBackfillIncrementalTurnActivity
        ) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(periodStart, forKey: .periodStart)
        try container.encode(turns, forKey: .turns)
        try container.encode(snapshots, forKey: .snapshots)
        try container.encode(events, forKey: .events)
        try container.encode(logByteOffsets, forKey: .logByteOffsets)
        try container.encode(didBackfillTurnEndedAt, forKey: .didBackfillTurnEndedAt)
        try container.encode(didBackfillIncrementalTurnActivity, forKey: .didBackfillIncrementalTurnActivity)
    }
}
