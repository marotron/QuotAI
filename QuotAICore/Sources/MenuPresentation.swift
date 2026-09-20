import Foundation

public struct QuotaMeter: Equatable, Sendable {
    public var name: String
    public var percentUsed: Double?
    /// Seconds until period reset; presentation uses days or hours via `RemainingTime`.
    public var secondsRemaining: TimeInterval?
    public var pace: PaceResult?
    public var isUnavailable: Bool
    public var periodStart: Date?
    public var periodEnd: Date?

    public init(
        name: String,
        percentUsed: Double? = nil,
        secondsRemaining: TimeInterval? = nil,
        pace: PaceResult? = nil,
        isUnavailable: Bool = false,
        periodStart: Date? = nil,
        periodEnd: Date? = nil
    ) {
        self.name = name
        self.percentUsed = percentUsed
        self.secondsRemaining = secondsRemaining
        self.pace = pace
        self.isUnavailable = isUnavailable
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
}

public enum BarDisplayMode: String, CaseIterable, Hashable, Sendable {
    case usedAndDays
    case pace
}

/// User setting: how the menu bar icon is colored.
public enum IconColorMode: String, CaseIterable, Hashable, Sendable {
    case monochrome
    case byLevel
}

/// Semantic tint for the icon; the app maps this to actual colors.
public enum SymbolTint: Equatable, Sendable {
    case neutral
    /// Under pace (`r < 0.90`) → blue.
    case under
    /// On pace / healthy usage → green.
    case ok
    case warning
    /// Over pace / critical usage / exhausted → red.
    case critical
}

public struct MenuPresentation: Equatable, Sendable {
    public var barTitle: String
    /// SF Symbol for the menu bar icon; tracks the worst meter (or pace in pace mode).
    public var symbolName: String
    public var tint: SymbolTint
    public var rows: [String]
    public var spendingURL: URL

    public init(barTitle: String, symbolName: String, tint: SymbolTint, rows: [String], spendingURL: URL) {
        self.barTitle = barTitle
        self.symbolName = symbolName
        self.tint = tint
        self.rows = rows
        self.spendingURL = spendingURL
    }
}

public enum MenuPresenter {
    public static let spendingURL = URL(string: "https://cursor.com/dashboard/spending")!

    public static func present(
        cursorModels: QuotaMeter,
        otherModels: QuotaMeter? = nil,
        grokBot: QuotaMeter,
        mode: BarDisplayMode,
        authError: String? = nil
    ) -> MenuPresentation {
        var rows = [row(cursorModels), otherModels.map(row), row(grokBot)].compactMap { $0 }
        if let authError, !authError.isEmpty {
            rows.insert(authError, at: 0)
        }
        let barTitle: String
        let symbolName: String
        let tint: SymbolTint
        if authError != nil {
            barTitle = "QuotAI · auth"
            symbolName = "exclamationmark.triangle"
            tint = .critical
        } else {
            let level: Double?
            switch mode {
            case .usedAndDays:
                barTitle = glanceUsed(cursorModels, grokBot)
                level = worstPercentUsed(cursorModels, grokBot)
            case .pace:
                barTitle = glancePace(cursorModels, grokBot)
                level = worstPaceRatio(cursorModels, grokBot).map { $0 * 100 }
            }
            symbolName = gaugeSymbol(level: level)
            tint = Self.tint(level: level)
        }
        return MenuPresentation(
            barTitle: barTitle,
            symbolName: symbolName,
            tint: tint,
            rows: rows,
            spendingURL: spendingURL
        )
    }

    /// 0–100 level → semantic tint (also used per bar by the app icon).
    public static func tint(level: Double?) -> SymbolTint {
        guard let level else { return .neutral }
        if level >= 80 { return .critical }
        if level >= 50 { return .warning }
        return .ok
    }

    /// Pace ratio → Under / On / Over colors (locked formula green band 0.90…1.10).
    public static func tint(pace: PaceResult?) -> SymbolTint {
        guard let pace else { return .neutral }
        if pace.daysToExhaustion == 0 { return .critical } // Exhausted
        guard let r = pace.ratio else { return .neutral }
        if r < PaceCalculator.greenLo { return .under }
        if r > PaceCalculator.greenHi { return .critical }
        return .ok
    }

    private static func worstPercentUsed(_ a: QuotaMeter, _ b: QuotaMeter) -> Double? {
        [a, b].compactMap { $0.isUnavailable ? nil : $0.percentUsed }.max()
    }

    private static func worstPaceRatio(_ a: QuotaMeter, _ b: QuotaMeter) -> Double? {
        [a, b].compactMap { $0.isUnavailable ? nil : $0.pace?.ratio }.max()
    }

    /// Snaps 0–100 to the nearest available `gauge.with.dots.needle.*percent` symbol.
    private static func gaugeSymbol(level: Double?) -> String {
        let steps = [0, 33, 50, 67, 100]
        let value = min(100, max(0, level ?? 0))
        let nearest = steps.min { abs(Double($0) - value) < abs(Double($1) - value) } ?? 0
        return "gauge.with.dots.needle.\(nearest)percent"
    }

    private static func row(_ m: QuotaMeter) -> String {
        if m.isUnavailable {
            return "\(m.name): unavailable"
        }
        guard let pct = m.percentUsed else {
            return "\(m.name): —"
        }
        // Menu: raw API % + detailed reset clock; bar keeps ceiled whole % via BarIcon.
        let remaining = m.secondsRemaining.map(RemainingTime.formatDetailed(seconds:)) ?? "—"
        let pace = m.pace?.label ?? "Pace n/a"
        return "\(m.name): \(QuotaPercent.precise(pct)) · \(remaining) · \(pace)"
    }

    private static func glanceUsed(_ a: QuotaMeter, _ b: QuotaMeter) -> String {
        let parts = [a, b].compactMap { m -> String? in
            guard !m.isUnavailable, let pct = m.percentUsed else { return nil }
            let remaining = m.secondsRemaining.map(RemainingTime.format(seconds:)) ?? "?"
            return "\(short(m.name)) \(formatPct(pct))/\(remaining)"
        }
        return parts.isEmpty ? "QuotAI" : parts.joined(separator: " · ")
    }

    private static func glancePace(_ a: QuotaMeter, _ b: QuotaMeter) -> String {
        guard let worst = worstPaceRatio(a, b) else { return "QuotAI" }
        let pct = Int((worst * 100).rounded())
        return "Pace \(pct)%"
    }

    private static func short(_ name: String) -> String {
        name == "Grok Bot" ? "Grok" : "Cur"
    }

    private static func formatPct(_ value: Double) -> String {
        QuotaPercent.format(value)
    }
}
