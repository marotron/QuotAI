import AppKit
import QuotAICore

/// Single-row menu-bar ring dials (proto A / B / G at 22pt).
enum RingIcon {
    struct Dial {
        var avatar: BarIcon.Avatar
        /// Show avatar for this dial (Other Models in per-quota layout has none).
        var showAvatar: Bool
        /// One fill, or Models + Other concentric (outer → inner).
        var usedPcts: [Double?]
        /// Fill colors parallel to `usedPcts` (A/B by-pace → pace tint); ignored for pace-look arcs / mono.
        var brandColors: [NSColor?]
        /// Center / beside avatar tint; nil → first fill color, else ink.
        var avatarColor: NSColor? = nil
        /// 0–100 period elapsed; nil → no timeline (and no beside elapsed %).
        var elapsedPct: Double?
        var remaining: String?
        /// Which `usedPcts` index drives the beside used % (B Models ↔ Other blink).
        var displayedUsedIndex: Int
    }

    private struct Metrics {
        let height: CGFloat = 22
        let midY: CGFloat = 11
        let avatar: CGFloat = 10
        let centerAvatar: CGFloat = 8.5
        let ringD: CGFloat = 20
        var ringR: CGFloat { ringD / 2 }
        let gap: CGFloat = 3
        let ringGap: CGFloat = 3
        let avatarGap: CGFloat = 2
        let metricGap: CGFloat = 2
        let outerR: CGFloat = 9.2
        let timelineStroke: CGFloat = 0.8
        let quotaStroke: CGFloat = 1.6
        let ringGapStroke: CGFloat = 0.55
        var singleStroke: CGFloat { quotaStroke * 2 }
        /// Dual used+elapsed stack beside the ring.
        let dualFont: NSFont = .monospacedDigitSystemFont(ofSize: 8, weight: .semibold)
        /// Single percent beside the ring (used or elapsed only).
        let singleFont: NSFont = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let besideRemainingFont: NSFont = .monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        let centerFont: NSFont = .systemFont(ofSize: 8.5, weight: .medium)
        /// Tighten remaining-time glyphs inside the ring.
        let centerKern: CGFloat = -0.9
    }

    static func image(
        look: IconLook,
        dials: [Dial],
        showAvatarsBeside: Bool,
        showUsedPercent: Bool,
        showElapsedPercent: Bool,
        showRemainingBeside: Bool,
        /// Non-nil → one beside slot blinks elapsed % ↔ time to reset (phase = show remaining).
        alternateShowsRemaining: Bool? = nil,
        ringCenter: RingCenterContent,
        colorMode: IconColorMode,
        onPaceLo: Double,
        onPaceHi: Double,
        foreground ink: NSColor,
        paceColor: @escaping (SymbolTint) -> NSColor
    ) -> NSImage {
        precondition(look != .bars, "RingIcon is for ring looks only")
        let m = Metrics()
        let style: RingDialSegments.Style = look == .ringsPace ? .paceUnderPale : .timelineBrand
        /// One text column: stack when exactly two beside values; three → % stack + remaining column.
        let besideColumns: [(cols: [[(text: String, faded: Bool)]], widthExtras: [String])] = dials.map { dial in
            var lines: [(text: String, faded: Bool)] = []
            var widthExtras: [String] = []
            if showUsedPercent {
                let usedIdx = min(max(dial.displayedUsedIndex, 0), max(dial.usedPcts.count - 1, 0))
                let used = dial.usedPcts.indices.contains(usedIdx)
                    ? dial.usedPcts[usedIdx].map { "\(QuotaPercent.display($0))%" } ?? "—"
                    : "—"
                lines.append((used, false))
            }
            if let showRem = alternateShowsRemaining {
                let elapsedText = dial.elapsedPct.map { "\(QuotaPercent.display($0))%" } ?? "—"
                let rem = dial.remaining ?? ""
                let remText = rem.isEmpty ? "—" : rem
                lines.append((showRem ? remText : elapsedText, !showRem))
                // Keep column width stable across phases.
                widthExtras.append(contentsOf: [elapsedText, remText])
            } else {
                if showElapsedPercent {
                    lines.append((dial.elapsedPct.map { "\(QuotaPercent.display($0))%" } ?? "—", true))
                }
                if showRemainingBeside {
                    let rem = dial.remaining ?? ""
                    lines.append((rem.isEmpty ? "—" : rem, false))
                }
            }
            let cols: [[(text: String, faded: Bool)]]
            switch lines.count {
            case 0:
                cols = []
            case 1, 2:
                cols = [lines]
            default:
                // used + elapsed stacked; remaining in its own column
                cols = [Array(lines.prefix(2)), Array(lines.suffix(1))]
            }
            return (cols, widthExtras)
        }
        let columnWidths: [CGFloat] = {
            guard let sample = besideColumns.first, !sample.cols.isEmpty else { return [] }
            return sample.cols.indices.map { col in
                var texts = besideColumns.compactMap { entry -> [String]? in
                    guard entry.cols.indices.contains(col) else { return nil }
                    return entry.cols[col].map(\.text)
                }.flatMap { $0 }
                if col == sample.cols.count - 1 {
                    texts.append(contentsOf: besideColumns.flatMap(\.widthExtras))
                }
                let lineCount = sample.cols[col].count
                let loneSingle = sample.cols.count == 1 && lineCount == 1
                let font: NSFont
                if loneSingle {
                    font = m.singleFont
                } else if lineCount > 1 {
                    font = m.dualFont
                } else {
                    font = m.besideRemainingFont
                }
                return textWidth(texts, font: font)
            }
        }()

        var width: CGFloat = 2
        for (i, dial) in dials.enumerated() {
            if i > 0 { width += m.ringGap }
            if showAvatarsBeside, dial.showAvatar { width += m.avatar + m.avatarGap }
            width += m.ringD
            for colWidth in columnWidths {
                width += m.metricGap + colWidth
            }
        }
        width += 2

        let image = NSImage(size: NSSize(width: width, height: m.height), flipped: true) { _ in
            var x: CGFloat = 2
            for (i, dial) in dials.enumerated() {
                if i > 0 { x += m.ringGap }
                let avatarColor: NSColor = {
                    if let custom = dial.avatarColor { return custom }
                    if colorMode == .byLevel, let brand = dial.brandColors.first ?? nil {
                        return brand
                    }
                    return ink
                }()
                if showAvatarsBeside, dial.showAvatar {
                    drawAvatar(
                        dial.avatar,
                        in: NSRect(x: x, y: m.midY - m.avatar / 2, width: m.avatar, height: m.avatar),
                        ink: avatarColor
                    )
                    x += m.avatar + m.avatarGap
                }
                let cx = x + m.ringR
                drawDial(
                    dial,
                    at: CGPoint(x: cx, y: m.midY),
                    style: style,
                    look: look,
                    colorMode: colorMode,
                    ringCenter: ringCenter,
                    avatarColor: avatarColor,
                    onPaceLo: onPaceLo,
                    onPaceHi: onPaceHi,
                    ink: ink,
                    paceColor: paceColor,
                    metrics: m
                )
                x += m.ringD
                let columns = besideColumns[i].cols
                for (col, lines) in columns.enumerated() {
                    let labelX = x + m.metricGap
                    let colWidth = columnWidths[col]
                    if lines.count == 2 {
                        drawText(lines[0].text, x: labelX, midY: m.midY - 4.5, font: m.dualFont, ink: ink)
                        drawText(
                            lines[1].text,
                            x: labelX,
                            midY: m.midY + 4.5,
                            font: m.dualFont,
                            ink: lines[1].faded ? ink.withAlphaComponent(0.72) : ink
                        )
                    } else if let only = lines.first {
                        let loneColumn = columns.count == 1
                        let font = loneColumn ? m.singleFont : m.besideRemainingFont
                        drawText(
                            only.text,
                            x: labelX,
                            midY: m.midY,
                            font: font,
                            ink: only.faded ? ink.withAlphaComponent(0.85) : ink
                        )
                    }
                    x += m.metricGap + colWidth
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Dial drawing

    private static func drawDial(
        _ dial: Dial,
        at center: CGPoint,
        style: RingDialSegments.Style,
        look: IconLook,
        colorMode: IconColorMode,
        ringCenter: RingCenterContent,
        avatarColor: NSColor,
        onPaceLo: Double,
        onPaceHi: Double,
        ink: NSColor,
        paceColor: (SymbolTint) -> NSColor,
        metrics m: Metrics
    ) {
        let useds = dial.usedPcts.map { $0.map { min(max($0, 0), 100) } ?? 0 }
        let stroke = useds.count > 1 ? m.quotaStroke : m.singleStroke
        let hasTimeline = look != .ringsPace && dial.elapsedPct != nil

        if hasTimeline, let elapsed = dial.elapsedPct {
            drawTimelineTrack(at: center, elapsedPct: elapsed, ink: ink, metrics: m)
        }

        for (index, used) in useds.enumerated() {
            let r = hasTimeline
                ? usedRadiusTimeline(index: index, stroke: stroke, metrics: m)
                : usedRadiusPace(index: index, stroke: stroke, metrics: m)
            drawPaleTrack(at: center, radius: r, stroke: stroke, ink: ink)

            let brand = index < dial.brandColors.count ? dial.brandColors[index] : nil
            let arcs = RingDialSegments.arcs(
                usedPct: used,
                elapsedPct: dial.elapsedPct ?? 0,
                style: style,
                onPaceLo: onPaceLo,
                onPaceHi: onPaceHi
            )
            for arc in arcs {
                let color = strokeColor(
                    tint: arc.tint,
                    brand: brand,
                    look: look,
                    colorMode: colorMode,
                    ink: ink,
                    paceColor: paceColor
                )
                strokePctArc(
                    at: center,
                    radius: r,
                    fromPct: arc.fromPct,
                    toPct: arc.toPct,
                    color: color,
                    width: stroke
                )
            }
        }

        switch ringCenter {
        case .none:
            break
        case .remaining:
            if let rem = dial.remaining, !rem.isEmpty {
                drawCenterRemaining(rem, at: center, font: m.centerFont, kern: m.centerKern, ink: ink)
            }
        case .icon:
            guard dial.showAvatar else { break }
            let s = m.centerAvatar
            drawAvatar(
                dial.avatar,
                in: NSRect(x: center.x - s / 2, y: center.y - s / 2, width: s, height: s),
                ink: avatarColor
            )
        }
    }

    private static func strokeColor(
        tint: RingDialSegments.Tint,
        brand: NSColor?,
        look: IconLook,
        colorMode: IconColorMode,
        ink: NSColor,
        paceColor: (SymbolTint) -> NSColor
    ) -> NSColor {
        if colorMode == .monochrome {
            switch tint {
            case .okPale: return ink.withAlphaComponent(0.28)
            case .brand, .under, .ok, .over: return ink
            }
        }
        // By-pace A/B: caller supplies pace tints via `brand` (same palette as bars).
        // Rings · pace (G): arc tint drives the palette (incl. pale under-slack).
        if look != .ringsPace {
            return brand ?? ink
        }
        switch tint {
        case .brand: return brand ?? ink
        case .under: return paceColor(.under)
        case .ok: return paceColor(.ok)
        case .okPale: return paceColor(.ok).withAlphaComponent(0.28)
        case .over: return paceColor(.warning)
        }
    }

    private static func usedRadiusTimeline(index: Int, stroke: CGFloat, metrics m: Metrics) -> CGFloat {
        var r = m.outerR - m.timelineStroke / 2 - m.ringGapStroke - stroke / 2
        for _ in 0..<index { r -= stroke + m.ringGapStroke }
        return r
    }

    private static func usedRadiusPace(index: Int, stroke: CGFloat, metrics m: Metrics) -> CGFloat {
        var r = m.outerR - stroke / 2
        for _ in 0..<index { r -= stroke + m.ringGapStroke }
        return r
    }

    private static func drawTimelineTrack(at c: CGPoint, elapsedPct: Double, ink: NSColor, metrics m: Metrics) {
        let track = ink.withAlphaComponent(0.22)
        strokeFullCircle(at: c, radius: m.outerR, color: track, width: m.timelineStroke)
        let t = min(100, max(0, elapsedPct))
        if t > 0 {
            strokePctArc(at: c, radius: m.outerR, fromPct: 0, toPct: t, color: ink.withAlphaComponent(0.92), width: m.timelineStroke)
        }
    }

    private static func drawPaleTrack(at c: CGPoint, radius: CGFloat, stroke: CGFloat, ink: NSColor) {
        strokeFullCircle(at: c, radius: radius, color: ink.withAlphaComponent(0.18), width: stroke)
    }

    private static func strokeFullCircle(at c: CGPoint, radius: CGFloat, color: NSColor, width: CGFloat) {
        let path = NSBezierPath(ovalIn: NSRect(
            x: c.x - radius,
            y: c.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .butt
        path.stroke()
    }

    private static func strokePctArc(
        at c: CGPoint,
        radius: CGFloat,
        fromPct: Double,
        toPct: Double,
        color: NSColor,
        width: CGFloat
    ) {
        guard toPct > fromPct + 0.05 else { return }
        // Flipped image (y↓): 0% at 12 o'clock, progressing clockwise on screen.
        // Path angles: 0 = 3 o'clock; CCW in path space = CW on screen when flipped.
        let startAngle = -90 + fromPct * 3.6
        let endAngle = -90 + toPct * 3.6
        let path = NSBezierPath()
        path.appendArc(
            withCenter: c,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        color.setStroke()
        path.lineWidth = width
        path.lineCapStyle = .butt
        path.stroke()
    }

    // MARK: - Labels / avatars

    private static func drawCenterRemaining(
        _ text: String,
        at c: CGPoint,
        font: NSFont,
        kern: CGFloat,
        ink: NSColor
    ) {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: ink,
            .kern: kern,
        ])
        let size = attributed.size()
        attributed.draw(at: NSPoint(x: c.x - size.width / 2, y: c.y - size.height / 2))
    }

    private static func drawAvatar(_ avatar: BarIcon.Avatar, in box: NSRect, ink: NSColor) {
        let custom = NSImage(named: avatar.rawValue)
        let image = custom ?? fallbackAvatar(avatar, size: box.height)
        let drawBox = custom != nil ? box.insetBy(dx: box.width * 0.08, dy: box.height * 0.08) : box
        image?.draw(in: drawBox)
        if ink != .black {
            ink.setFill()
            box.fill(using: .sourceAtop)
        }
    }

    private static func fallbackAvatar(_ avatar: BarIcon.Avatar, size: CGFloat) -> NSImage? {
        let name: String
        switch avatar {
        case .cursor: name = "cube.fill"
        case .grok: name = "circle.fill"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
    }

    private static func textWidth(_ texts: [String], font: NSFont) -> CGFloat {
        ceil(texts.map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }.max() ?? 0)
    }

    private static func drawText(_ text: String, x: CGFloat, midY: CGFloat, font: NSFont, ink: NSColor) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink])
        attributed.draw(at: NSPoint(x: x, y: midY - attributed.size().height / 2))
    }
}
