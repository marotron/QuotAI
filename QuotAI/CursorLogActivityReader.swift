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
    }

    /// Current sizes of Agent Host logs, keyed by absolute path.
    /// Used once after upgrade when turns already exist but offsets were never stored —
    /// treat EOF as consumed so cold start does not re-parse historical logs.
    func currentFileSizes() -> [String: UInt64] {
        Dictionary(uniqueKeysWithValues: logFiles().compactMap { url in
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
        for url in logFiles() {
            let path = url.path
            let (fileTurns, newOffset) = readNewTurns(
                from: url,
                priorOffset: offsets[path] ?? 0,
                knownTurns: Array(byUUID.values)
            )
            offsets[path] = newOffset
            for turn in fileTurns {
                let key = turn.generationUUID.lowercased()
                mentioned.insert(key)
                if var existing = byUUID[key] {
                    if let incomingEnd = turn.endedAt,
                       existing.endedAt.map({ incomingEnd > $0 }) ?? true
                    {
                        existing.endedAt = incomingEnd
                        byUUID[key] = existing
                    }
                } else {
                    byUUID[key] = turn
                }
            }
        }
        let turns = mentioned.compactMap { byUUID[$0] }.sorted { $0.timestamp < $1.timestamp }
        return ReadResult(turns: turns, offsets: offsets)
    }

    private func logFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: logsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("Cursor Agent Host")
                && name.hasSuffix(".log")
                && !name.contains("Storage")
                && !name.contains("Network")
        }
    }

    private func readNewTurns(
        from url: URL,
        priorOffset: UInt64,
        knownTurns: [CursorAgentTurn]
    ) -> (turns: [CursorAgentTurn], offset: UInt64) {
        guard let size = (try? url.resourceValues(forKeys: [.fileSizeKey])).flatMap(\.fileSize)
        else {
            return ([], priorOffset)
        }
        let currentSize = UInt64(size)
        // Truncation / rotation: prior cursor past EOF → re-read from the start.
        let offset = priorOffset > currentSize ? 0 : priorOffset
        guard offset < currentSize else {
            return ([], currentSize)
        }
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ([], priorOffset)
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset)
            let data = try handle.readToEnd() ?? Data()
            guard let text = String(data: data, encoding: .utf8) else {
                return ([], currentSize)
            }
            return (CursorActivityParser.parse(log: text, knownTurns: knownTurns), currentSize)
        } catch {
            return ([], priorOffset)
        }
    }
}
