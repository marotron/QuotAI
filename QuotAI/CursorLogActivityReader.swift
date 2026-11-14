import Foundation
import QuotAICore

/// Incrementally reads the Agent Host runtime records from Cursor's local logs.
/// Offsets are passed in/out so the activity store can persist them across launches.
final class CursorLogActivityReader: @unchecked Sendable {
    private let logsDirectory: URL

    init(
        logsDirectory: URL = URL(
            fileURLWithPath: NSHomeDirectory(),
            isDirectory: true
        )
        .appendingPathComponent("Library/Application Support/Cursor/logs", isDirectory: true)
    ) {
        self.logsDirectory = logsDirectory
    }

    struct ReadResult: Sendable {
        var turns: [CursorAgentTurn]
        var offsets: [String: UInt64]
        var isComplete: Bool
    }

    /// Current sizes of Agent Host logs, keyed by absolute path.
    /// Used once after upgrade when turns already exist but offsets were never stored —
    /// treat EOF as consumed so cold start does not re-parse historical logs.
    func currentFileSizes() -> [String: UInt64] {
        Dictionary(uniqueKeysWithValues: (logFiles() ?? []).compactMap { url in
            guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey])).flatMap(\.fileSize)
            else {
                return nil
            }
            return (url.path, UInt64(size))
        })
    }

    func readNewTurns(priorOffsets: [String: UInt64], knownTurns: [CursorAgentTurn] = []) -> ReadResult {
        var offsets = priorOffsets
        var byUUID: [String: CursorAgentTurn] = [:]
        for turn in knownTurns {
            byUUID[turn.generationUUID.lowercased()] = turn
        }
        var mentioned = Set<String>()
        let files = logFiles()
        var isComplete = files != nil
        for url in files ?? [] {
            let path = url.path
            let (fileTurns, newOffset, succeeded) = readNewTurns(
                from: url,
                priorOffset: offsets[path] ?? 0,
                knownTurns: Array(byUUID.values)
            )
            offsets[path] = newOffset
            isComplete = isComplete && succeeded
            for turn in fileTurns {
                let key = turn.generationUUID.lowercased()
                mentioned.insert(key)
                if var existing = byUUID[key] {
                    if let incomingEnd = turn.endedAt,
                       existing.endedAt.map({ incomingEnd > $0 }) ?? true
                    {
                        existing.endedAt = incomingEnd
                    }
                    if let reason = turn.routingReason { existing.routingReason = reason }
                    if let conversation = turn.conversationID { existing.conversationID = conversation }
                    byUUID[key] = existing
                } else {
                    byUUID[key] = turn
                }
            }
        }
        let turns = mentioned.compactMap { byUUID[$0] }.sorted { $0.timestamp < $1.timestamp }
        return ReadResult(turns: turns, offsets: offsets, isComplete: isComplete)
    }

    private func logFiles() -> [URL]? {
        var failed = false
        guard let enumerator = FileManager.default.enumerator(
            at: logsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in failed = true; return true }
        ) else {
            return nil
        }
        let files = enumerator.compactMap { $0 as? URL }.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("Cursor Agent Host")
                && name.hasSuffix(".log")
                && !name.contains("Storage")
                && !name.contains("Network")
        }
        return failed ? nil : files
    }

    private func readNewTurns(
        from url: URL,
        priorOffset: UInt64,
        knownTurns: [CursorAgentTurn]
    ) -> (turns: [CursorAgentTurn], offset: UInt64, succeeded: Bool) {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey])).flatMap(\.fileSize)
        else {
            return ([], priorOffset, false)
        }
        let currentSize = UInt64(size)
        // Truncation / rotation: prior cursor past EOF → re-read from the start.
        let offset = priorOffset > currentSize ? 0 : priorOffset
        guard offset < currentSize else {
            return ([], currentSize, true)
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ([], priorOffset, false)
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            // Only consume complete records from the size snapshot. Cursor may still be
            // writing the last line (including a split UTF-8 character) during a poll.
            let data = try handle.read(upToCount: Int(currentSize - offset)) ?? Data()
            guard let lastNewline = data.lastIndex(of: 0x0A) else {
                return ([], offset, true)
            }
            let complete = data.prefix(through: lastNewline)
            let text = String(decoding: complete, as: UTF8.self)
            return (CursorActivityParser.parse(log: text, knownTurns: knownTurns), offset + UInt64(complete.count), true)
        } catch {
            return ([], priorOffset, false)
        }
    }
}
