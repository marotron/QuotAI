import Foundation
import CoreFoundation

public struct CursorUsageBillingRecord: Equatable, Sendable {
    public var id: String
    public var timestamp: Date
    public var modelID: String
    public var conversationID: String?
    public var isChargeable: Bool?
}

public struct CursorUsageBillingPage: Sendable {
    public var records: [CursorUsageBillingRecord]
    public var totalCount: Int

    public static func parse(_ data: Data) throws -> Self {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = object["totalUsageEventsCount"] as? Int, total >= 0
        else { throw CocoaError(.coderReadCorrupt) }
        let rows = object["usageEventsDisplay"] as? [[String: Any]] ?? []
        if rows.isEmpty && total > 0 { throw CocoaError(.coderReadCorrupt) }
        let records = try rows.map { row -> CursorUsageBillingRecord in
            guard let id = row["usageEventId"] as? String, !id.isEmpty,
                  let model = row["model"] as? String, !model.isEmpty,
                  let milliseconds = (row["timestamp"] as? NSNumber)?.doubleValue
                    ?? (row["timestamp"] as? String).flatMap(Double.init),
                  milliseconds.isFinite, milliseconds > 0
            else { throw CocoaError(.coderReadCorrupt) }
            let flag = row["isChargeable"] as? NSNumber
            let chargeable = flag.flatMap { CFGetTypeID($0) == CFBooleanGetTypeID() ? $0.boolValue : nil }
            return CursorUsageBillingRecord(
                id: id, timestamp: Date(timeIntervalSince1970: milliseconds / 1000), modelID: model,
                conversationID: row["conversationId"] as? String, isChargeable: chargeable
            )
        }
        return Self(records: records, totalCount: total)
    }
}

public struct CursorBillingCheck: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable { case chargeable, nonChargeable, unknown }
    public var status: Status
    public var checkedAt: Date
    public var activityEnd: Date
    public var eventIDs: [String]

    public func covers(_ turn: CursorAgentTurn) -> Bool {
        activityEnd >= (turn.endedAt ?? turn.timestamp)
    }
}

public struct CursorUsageBillingWindow: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var turnIDs: [String]
}

/// Billing lookups are bounded enrichment of existing unmatched activity, not a polling feed.
public enum CursorUsageBilling {
    public static let minimumLookupInterval: TimeInterval = 10 * 60
    public static let maxWindows = 2
    public static let maxWindowDuration: TimeInterval = 60 * 60
    public static let timestampTolerance: TimeInterval = 2

    public static func windows(
        events: [CursorDiscrepancyEvent], turns: [CursorAgentTurn], checks: [String: CursorBillingCheck],
        lastLookup: Date?, now: Date
    ) -> [CursorUsageBillingWindow] {
        if let lastLookup, now.timeIntervalSince(lastLookup) < minimumLookupInterval { return [] }
        let unmatched = Set(events.filter { $0.kind == .unbilledActivity }.flatMap(\.generationUUIDs))
        let candidates = turns.filter { turn in
            guard unmatched.contains(turn.generationUUID), !turn.isOutsideCursorBilling,
                  let conversation = turn.conversationID, !conversation.isEmpty,
                  let model = turn.modelID, !model.isEmpty,
                  (turn.endedAt ?? turn.timestamp).timeIntervalSince(turn.timestamp) + 2 * timestampTolerance <= maxWindowDuration
            else { return false }
            guard let check = checks[turn.generationUUID], check.covers(turn) else { return true }
            if check.status != .unknown { return false }
            let retry: TimeInterval = now.timeIntervalSince(turn.timestamp) < 60 * 60 ? minimumLookupInterval : 24 * 60 * 60
            return now.timeIntervalSince(check.checkedAt) >= retry
        }.sorted { $0.timestamp > $1.timestamp }

        var result: [CursorUsageBillingWindow] = []
        for turn in candidates {
            let start = turn.timestamp.addingTimeInterval(-timestampTolerance)
            let end = (turn.endedAt ?? turn.timestamp).addingTimeInterval(timestampTolerance)
            if let index = result.indices.first(where: {
                let window = result[$0]
                let gap = max(window.start, start).timeIntervalSince(min(window.end, end))
                return gap <= 5 * 60 && max(window.end, end).timeIntervalSince(min(window.start, start)) <= maxWindowDuration
            }) {
                result[index].start = min(result[index].start, start)
                result[index].end = max(result[index].end, end)
                result[index].turnIDs.append(turn.generationUUID)
            } else if result.count < maxWindows {
                result.append(CursorUsageBillingWindow(start: start, end: end, turnIDs: [turn.generationUUID]))
            }
        }
        return result
    }

    /// Require a unique conversation/model/time association, an initial record close
    /// to turn start, and a complete query across the whole observed activity interval.
    /// A Free first attempt followed by a chargeable retry must never suppress a turn.
    public static func checks(
        for window: CursorUsageBillingWindow, records: [CursorUsageBillingRecord],
        complete: Bool, turns: [CursorAgentTurn], now: Date
    ) -> [String: CursorBillingCheck] {
        func matches(_ record: CursorUsageBillingRecord, _ turn: CursorAgentTurn) -> Bool {
            guard let conversation = turn.conversationID, !conversation.isEmpty,
                  conversation == record.conversationID, let model = turn.modelID,
                  normalized(model) == normalized(record.modelID)
            else { return false }
            return record.timestamp >= turn.timestamp.addingTimeInterval(-timestampTolerance)
                && record.timestamp <= (turn.endedAt ?? turn.timestamp).addingTimeInterval(timestampTolerance)
        }
        let groups = Dictionary(grouping: records, by: \.id)
        let consistent = groups.values.allSatisfy { group in group.allSatisfy { $0 == group[0] } }
        let uniqueRecords = groups.values.compactMap { group in
            group.allSatisfy { $0 == group[0] } ? group[0] : nil
        }
        let targetIDs = Set(window.turnIDs)
        var output: [String: CursorBillingCheck] = [:]
        for turn in turns where targetIDs.contains(turn.generationUUID) {
            let related = uniqueRecords.filter { matches($0, turn) }
            let anchored = related.contains { abs($0.timestamp.timeIntervalSince(turn.timestamp)) <= timestampTolerance }
            let covered = window.start <= turn.timestamp.addingTimeInterval(-timestampTolerance)
                && window.end >= (turn.endedAt ?? turn.timestamp).addingTimeInterval(timestampTolerance)
            let unambiguous = related.allSatisfy { record in turns.filter { matches(record, $0) }.count == 1 }
            var status = CursorBillingCheck.Status.unknown
            if complete && covered && consistent && anchored && unambiguous && !related.isEmpty {
                if related.contains(where: { $0.isChargeable == true }) { status = .chargeable }
                else if related.allSatisfy({ $0.isChargeable == false }) { status = .nonChargeable }
            }
            output[turn.generationUUID] = CursorBillingCheck(
                status: status, checkedAt: now, activityEnd: turn.endedAt ?? turn.timestamp,
                eventIDs: related.map(\.id).sorted()
            )
        }
        return output
    }

    private static func normalized(_ model: String) -> String {
        let value = model.lowercased()
        return value == "default" ? "auto" : value
    }
}
