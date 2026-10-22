import Foundation

public struct ChangelogSection: Equatable, Sendable, Identifiable {
    public var id: String { title }
    public let title: String
    public let items: [String]

    public init(title: String, items: [String]) {
        self.title = title
        self.items = items
    }
}

public struct ChangelogRelease: Equatable, Sendable, Identifiable {
    public var id: String { version }
    public let version: String
    public let date: String
    public let sections: [ChangelogSection]

    public init(version: String, date: String, sections: [ChangelogSection]) {
        self.version = version
        self.date = date
        self.sections = sections
    }
}

/// Parses QuotAI-style changelog headers: `## X.Y.Z — YYYY-MM-DD` (no brackets).
public enum ChangelogParser {
    public static func parseReleases(_ raw: String) -> [ChangelogRelease] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("## ") else { return [] }

        // Uniform split: every release header is preceded by "\n## ".
        let normalized = trimmed.hasPrefix("## ") ? "\n\(trimmed)" : trimmed
        guard normalized.contains("\n## ") else { return [] }

        return normalized
            .components(separatedBy: "\n## ")
            .dropFirst()
            .compactMap(parseReleaseBlock)
    }

    private static func parseReleaseBlock(_ block: String) -> ChangelogRelease? {
        let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let header = lines.first else { return nil }

        let parts = header.components(separatedBy: " — ")
        guard parts.count == 2 else { return nil }
        let version = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let date = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty, !date.isEmpty else { return nil }

        let remainder = lines.dropFirst().joined(separator: "\n")
        return ChangelogRelease(
            version: version,
            date: date,
            sections: parseSections(from: remainder)
        )
    }

    private static func parseSections(from body: String) -> [ChangelogSection] {
        let normalized = body.hasPrefix("### ") ? "\n" + body : body
        return normalized
            .components(separatedBy: "\n### ")
            .dropFirst()
            .compactMap { block in
                let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                guard let title = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
                    return nil
                }
                let items = lines.dropFirst()
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { $0.hasPrefix("- ") }
                    .map { String($0.dropFirst(2)) }
                guard !items.isEmpty else { return nil }
                return ChangelogSection(title: title, items: items)
            }
    }
}
