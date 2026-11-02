import Foundation

/// Stable ids for pace-history series (menu meters).
public enum PaceHistoryMeterId: String, Codable, Hashable, Sendable, CaseIterable {
    case cursor
    case other
    case grok
}

/// One refresh sample on the used % × elapsed % plane.
public struct PaceHistorySample: Equatable, Codable, Sendable {
    public var meterId: PaceHistoryMeterId
    /// Used quota percent (0…100).
    public var usedPct: Double
    /// Billing-window elapsed percent (0…100).
    public var elapsedPct: Double
    public var timestamp: Date
    /// Billing window start; changing this rolls the meter’s series.
    public var periodStart: Date

    public init(
        meterId: PaceHistoryMeterId,
        usedPct: Double,
        elapsedPct: Double,
        timestamp: Date,
        periodStart: Date
    ) {
        self.meterId = meterId
        self.usedPct = usedPct
        self.elapsedPct = elapsedPct
        self.timestamp = timestamp
        self.periodStart = periodStart
    }
}

/// File-backed history of pace samples, one series per meter.
public final class PaceHistorySampleStore: @unchecked Sendable {
    public static let defaultFileName = "pace-history.json"

    public static var defaultFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("dev.marotron.QuotAI", isDirectory: true)
            .appendingPathComponent(defaultFileName)
    }

    private let fileURL: URL
    private let lock = NSLock()
    private var samples: [PaceHistorySample]

    public init(fileURL: URL = PaceHistorySampleStore.defaultFileURL) {
        self.fileURL = fileURL
        self.samples = Self.load(from: fileURL)
    }

    /// Samples for `meterId` in append order.
    public func series(for meterId: PaceHistoryMeterId) -> [PaceHistorySample] {
        lock.lock()
        defer { lock.unlock() }
        return samples.filter { $0.meterId == meterId }
    }

    /// Append a sample. Clears that meter’s series when `periodStart` differs from the stored period.
    public func append(_ sample: PaceHistorySample) throws {
        lock.lock()
        defer { lock.unlock() }
        applyAppend(sample)
        try Self.save(samples, to: fileURL)
    }

    /// Append several samples (each may roll its own meter).
    public func append(contentsOf batch: [PaceHistorySample]) throws {
        guard !batch.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        for sample in batch {
            applyAppend(sample)
        }
        try Self.save(samples, to: fileURL)
    }

    private func applyAppend(_ sample: PaceHistorySample) {
        if let existingPeriod = samples.first(where: { $0.meterId == sample.meterId })?.periodStart,
           existingPeriod != sample.periodStart {
            samples.removeAll { $0.meterId == sample.meterId }
        }
        samples.append(sample)
    }

    // MARK: - Persistence

    private struct DiskPayload: Codable {
        var samples: [PaceHistorySample]
    }

    private static func load(from url: URL) -> [PaceHistorySample] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let payload = try? JSONDecoder().decode(DiskPayload.self, from: data) else { return [] }
        return payload.samples
    }

    private static func save(_ samples: [PaceHistorySample], to url: URL) throws {
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(DiskPayload(samples: samples))
        try data.write(to: url, options: .atomic)
    }
}
