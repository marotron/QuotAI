import Foundation

/// Chart series visibility driven by meter-avatar clicks (solo → hide → all).
public enum PaceHistorySeriesFilterMode: String, Equatable, Sendable {
    case all
    case solo
    case hide
}

/// Per-avatar chrome while a series filter is active.
public enum PaceHistorySeriesAvatarCycle: String, Equatable, Sendable {
    /// Default / idle (or non-focus meter while another is hidden).
    case all
    /// Focus meter in solo mode.
    case solo
    /// Non-focus meter while another is solo.
    case dim
    /// Focus meter in hide mode.
    case hide
}

/// Panel filter: which pace-history meter series paint on the chart.
public struct PaceHistorySeriesFilter: Equatable, Sendable {
    public var mode: PaceHistorySeriesFilterMode
    public var focus: PaceHistoryMeterId?

    public static let all = PaceHistorySeriesFilter(mode: .all, focus: nil)

    public init(mode: PaceHistorySeriesFilterMode, focus: PaceHistoryMeterId?) {
        self.mode = mode
        self.focus = focus
    }

    /// Whether `id` should paint on the chart / tip.
    public func isVisible(_ id: PaceHistoryMeterId) -> Bool {
        switch mode {
        case .all:
            return true
        case .solo:
            guard let focus else { return true }
            return id == focus
        case .hide:
            guard let focus else { return true }
            return id != focus
        }
    }

    /// Avatar ring / dim / hide chrome for a meter row.
    public func avatarCycle(for id: PaceHistoryMeterId) -> PaceHistorySeriesAvatarCycle {
        guard let focus else { return .all }
        switch mode {
        case .all:
            return .all
        case .solo:
            return id == focus ? .solo : .dim
        case .hide:
            return id == focus ? .hide : .all
        }
    }

    /// Advance the 3-state cycle for a tapped meter avatar.
    /// Same meter: all → solo → hide → all. Different meter (or from all): jump to solo on that meter.
    public func cycling(tapped id: PaceHistoryMeterId) -> PaceHistorySeriesFilter {
        if mode == .all || focus != id {
            return PaceHistorySeriesFilter(mode: .solo, focus: id)
        }
        if mode == .solo {
            return PaceHistorySeriesFilter(mode: .hide, focus: id)
        }
        return .all
    }
}
