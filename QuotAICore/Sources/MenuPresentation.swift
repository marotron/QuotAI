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

    /// 0–100 how far through the billing period we are (nil if dates missing).
    public func periodElapsedPercent(now: Date = Date()) -> Double? {
        guard let start = periodStart, let end = periodEnd else { return nil }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return nil }
        return min(max(now.timeIntervalSince(start) / total, 0), 1) * 100
    }
}

/// User setting: how the menu bar icon is colored.
public enum IconColorMode: String, CaseIterable, Hashable, Sendable {
    case monochrome
    case byLevel
}

/// User setting: bars vs ring-dial menu bar glyph.
public enum IconLook: String, CaseIterable, Hashable, Sendable {
    /// Linear tracks (existing `BarIcon`).
    case bars
    /// Proto A — one ring per meter + timeline.
    case ringsPerQuota
    /// Proto B — Cursor concentric + Grok + timeline; used % blinks Models ↔ Other.
    case ringsPaired
    /// Proto G — pace segments with pale under-slack (no timeline track).
    case ringsPace

    /// Elapsed % ↔ time to reset shares one beside slot on every ring style.
    public var alternatesElapsedAndRemaining: Bool {
        switch self {
        case .ringsPerQuota, .ringsPaired, .ringsPace: return true
        case .bars: return false
        }
    }
}

/// What (if anything) is drawn in the hollow of a ring dial.
public enum RingCenterContent: String, CaseIterable, Hashable, Sendable {
    case none
    case remaining
    case icon
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

/// How far off the green band a meter’s pace sits (drives ice/fire shade).
public enum PaceShade: Int, Equatable, Sendable, Comparable {
    case none = 0
    case mild = 1
    case medium = 2
    case strong = 3

    public static func < (lhs: PaceShade, rhs: PaceShade) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum PaceBand: Equatable, Sendable {
    case unavailable
    case neutral
    case under
    case on
    case over
    case exhausted
}

/// One dropdown meter block: main line + optional smaller note + pace styling.
public struct MenuMeterRow: Equatable, Identifiable, Sendable {
    public var id: String { name }
    public var name: String
    /// e.g. `1.64% used / 2% elapsed → 82% pace · 29d 10h`
    public var title: String
    /// Smaller secondary line (waste % or early-empty / idle days).
    public var note: String?
    public var band: PaceBand
    public var shade: PaceShade
    /// SF Symbol: `snowflake` / `checkmark` / `flame.fill` / nil.
    public var symbolName: String?

    public init(
        name: String,
        title: String,
        note: String? = nil,
        band: PaceBand = .neutral,
        shade: PaceShade = .none,
        symbolName: String? = nil
    ) {
        self.name = name
        self.title = title
        self.note = note
        self.band = band
        self.shade = shade
        self.symbolName = symbolName
    }
}

public struct MenuPresentation: Equatable, Sendable {
    public var barTitle: String
    /// SF Symbol for the menu bar icon; tracks the worst meter (or pace in pace mode).
    public var symbolName: String
    public var tint: SymbolTint
    public var meters: [MenuMeterRow]
    /// Auth / other plain lines above the meters.
    public var notices: [String]
    public var spendingURL: URL

    public init(
        barTitle: String,
        symbolName: String,
        tint: SymbolTint,
        meters: [MenuMeterRow],
        notices: [String] = [],
        spendingURL: URL
    ) {
        self.barTitle = barTitle
        self.symbolName = symbolName
        self.tint = tint
        self.meters = meters
        self.notices = notices
        self.spendingURL = spendingURL
    }
}

public enum MenuPresenter {
    public static let spendingURL = URL(string: "https://cursor.com/dashboard/spending")!

    public static func present(
        cursorModels: QuotaMeter,
        otherModels: QuotaMeter? = nil,
        grokBot: QuotaMeter,
        authError: String? = nil,
        /// Transient fetch problem. Shown in the menu; does not replace the bar icon.
        notice: String? = nil,
        now: Date = Date(),
        onPaceLo: Double = PaceCalculator.greenLo,
        onPaceHi: Double = PaceCalculator.greenHi
    ) -> MenuPresentation {
        let lo = min(onPaceLo, onPaceHi)
        let hi = max(onPaceLo, onPaceHi)
        var meters = [meterRow(cursorModels, now: now, onPaceLo: lo, onPaceHi: hi)]
        if let otherModels {
            meters.append(meterRow(otherModels, now: now, onPaceLo: lo, onPaceHi: hi))
        }
        meters.append(meterRow(grokBot, now: now, onPaceLo: lo, onPaceHi: hi))
        var notices: [String] = []
        if let notice, !notice.isEmpty {
            notices.append(notice)
        }
        if let authError, !authError.isEmpty {
            notices.append(authError)
        }
        let barTitle: String
        let symbolName: String
        let tint: SymbolTint
        if authError != nil {
            barTitle = "QuotAI · auth"
            symbolName = "exclamationmark.triangle"
            tint = .critical
        } else {
            barTitle = glanceUsed(cursorModels, grokBot)
            let level = worstPercentUsed(cursorModels, grokBot)
            symbolName = gaugeSymbol(level: level)
            tint = Self.tint(level: level)
        }
        return MenuPresentation(
            barTitle: barTitle,
            symbolName: symbolName,
            tint: tint,
            meters: meters,
            notices: notices,
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

    /// Pace ratio → Under / On / Over colors. Same dead zone as dropdown bands.
    public static func tint(
        pace: PaceResult?,
        onPaceLo: Double = PaceCalculator.greenLo,
        onPaceHi: Double = PaceCalculator.greenHi
    ) -> SymbolTint {
        guard let pace else { return .neutral }
        if pace.daysToExhaustion == 0 { return .critical } // Exhausted
        guard let r = pace.ratio else { return .neutral }
        let lo = min(onPaceLo, onPaceHi)
        let hi = max(onPaceLo, onPaceHi)
        if PaceCalculator.isOnPace(r, lo: lo, hi: hi) { return .ok }
        if r < lo { return .under }
        // Over → orange (warning); exhausted stays critical/red above.
        return .warning
    }

    private static func worstPercentUsed(_ a: QuotaMeter, _ b: QuotaMeter) -> Double? {
        [a, b].compactMap { $0.isUnavailable ? nil : $0.percentUsed }.max()
    }

    /// Snaps 0–100 to the nearest available `gauge.with.dots.needle.*percent` symbol.
    private static func gaugeSymbol(level: Double?) -> String {
        let steps = [0, 33, 50, 67, 100]
        let value = min(100, max(0, level ?? 0))
        let nearest = steps.min { abs(Double($0) - value) < abs(Double($1) - value) } ?? 0
        return "gauge.with.dots.needle.\(nearest)percent"
    }

    private static func meterRow(
        _ m: QuotaMeter,
        now: Date,
        onPaceLo: Double,
        onPaceHi: Double
    ) -> MenuMeterRow {
        if m.isUnavailable {
            return MenuMeterRow(
                name: m.name,
                title: "\(m.name): unavailable",
                band: .unavailable
            )
        }
        guard let pct = m.percentUsed else {
            return MenuMeterRow(name: m.name, title: "\(m.name): —")
        }

        let remaining = m.secondsRemaining.map(RemainingTime.formatDetailed(seconds:)) ?? "—"
        let used = QuotaPercent.precise(pct)
        let title: String
        if let elapsed = m.periodElapsedPercent(now: now) {
            let elapsedPct = Int(elapsed.rounded())
            title = "\(m.name): \(used) used / \(elapsedPct)% elapsed → \(paceArrow(m.pace)) · \(remaining)"
        } else {
            let pace = m.pace?.label ?? "Pace n/a"
            title = "\(m.name): \(used) used · \(remaining) · \(pace)"
        }

        let style = paceStyle(
            m.pace,
            secondsRemaining: m.secondsRemaining,
            onPaceLo: onPaceLo,
            onPaceHi: onPaceHi
        )
        return MenuMeterRow(
            name: m.name,
            title: title,
            note: style.note,
            band: style.band,
            shade: style.shade,
            symbolName: style.symbolName
        )
    }

    private struct PaceStyle {
        var band: PaceBand
        var shade: PaceShade
        var symbolName: String?
        var note: String?
    }

    private static func paceStyle(
        _ pace: PaceResult?,
        secondsRemaining: TimeInterval?,
        onPaceLo: Double,
        onPaceHi: Double
    ) -> PaceStyle {
        guard let pace else {
            return PaceStyle(band: .neutral, shade: .none, symbolName: nil, note: nil)
        }
        if pace.daysToExhaustion == 0 {
            return PaceStyle(
                band: .exhausted,
                shade: .strong,
                symbolName: "flame.fill",
                note: "Quota exhausted"
            )
        }
        guard let r = pace.ratio else {
            return PaceStyle(band: .neutral, shade: .none, symbolName: nil, note: nil)
        }

        // Dead zone alone decides under / on / over (ignore isEarly for band/tint).
        if PaceCalculator.isOnPace(r, lo: onPaceLo, hi: onPaceHi) {
            return PaceStyle(
                band: .on,
                shade: .none,
                symbolName: "checkmark",
                note: nil
            )
        }

        if r < onPaceLo {
            let waste = max(0, (1 - r) * 100)
            let wastePct = Int(waste.rounded())
            return PaceStyle(
                band: .under,
                shade: underShade(r),
                symbolName: "snowflake",
                note: "At this pace ~\(wastePct)% of quota unused by reset"
            )
        }

        return PaceStyle(
            band: .over,
            shade: overShade(r, onPaceHi: onPaceHi),
            symbolName: "flame.fill",
            note: overNote(pace: pace, secondsRemaining: secondsRemaining)
        )
    }

    /// Mild just under green → strong when far under.
    private static func underShade(_ r: Double) -> PaceShade {
        if r < 0.60 { return .strong }
        if r < PaceCalculator.significantLo { return .medium }
        return .mild
    }

    private static func overShade(_ r: Double, onPaceHi: Double) -> PaceShade {
        if r > 1.50 { return .strong }
        if r > PaceCalculator.significantHi { return .medium }
        if r > onPaceHi { return .mild }
        return .none
    }

    private static func overNote(pace: PaceResult, secondsRemaining: TimeInterval?) -> String? {
        guard let daysToEmpty = pace.daysToExhaustion, daysToEmpty > 0 else { return nil }
        let empty = RemainingTime.format(days: daysToEmpty)
        guard let secondsRemaining, secondsRemaining > 0 else {
            return "Empties in ~\(empty)"
        }
        let daysLeftInPeriod = secondsRemaining / RemainingTime.day
        let idle = max(0, daysLeftInPeriod - daysToEmpty)
        if idle < 1.0 / 24.0 {
            // Less than ~1h of idle — just the empty timing.
            return "Empties in ~\(empty)"
        }
        let idleFmt = RemainingTime.format(days: idle)
        return "Empties in ~\(empty) · then ~\(idleFmt) with no quota"
    }

    /// `82% pace`, `Exhausted`, or `Pace n/a`.
    private static func paceArrow(_ pace: PaceResult?) -> String {
        guard let pace else { return "Pace n/a" }
        if pace.daysToExhaustion == 0 { return "Exhausted" }
        guard let r = pace.ratio else { return pace.label.isEmpty ? "Pace n/a" : pace.label }
        return "\(Int((r * 100).rounded()))% pace"
    }

    private static func glanceUsed(_ a: QuotaMeter, _ b: QuotaMeter) -> String {
        let parts = [a, b].compactMap { m -> String? in
            guard !m.isUnavailable, let pct = m.percentUsed else { return nil }
            let remaining = m.secondsRemaining.map(RemainingTime.format(seconds:)) ?? "?"
            return "\(short(m.name)) \(formatPct(pct))/\(remaining)"
        }
        return parts.isEmpty ? "QuotAI" : parts.joined(separator: " · ")
    }

    private static func short(_ name: String) -> String {
        name == "Grok Bot" ? "Grok" : "Cur"
    }

    private static func formatPct(_ value: Double) -> String {
        QuotaPercent.format(value)
    }
}
