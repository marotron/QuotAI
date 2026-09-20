import AppKit
import QuotAICore

/// Multi-row menu bar glyph: avatar · bar(s) · percent · time to reset.
/// Quota fill(s) share a group outline; optional time bar sits just under that group.
/// One composed image: MenuBarExtra labels only render a single image.
enum BarIcon {
    /// Which avatar a row draws; asset names double as catalog overrides.
    enum Avatar: String {
        case cursor = "CursorAvatar"
        case grok = "GrokAvatar"
    }

    struct Row {
        var avatar: Avatar
        /// One fill, or two glued fills (Cursor Models + Other Models).
        var fills: [Double?]
        var remaining: String?
        /// Parallel to `fills`; nil → use foreground ink.
        var barColors: [NSColor?]
        /// Pace tint for the avatar (light); nil → foreground ink. Dual Cursor may animate this.
        var avatarColor: NSColor?
        /// 0–100 period elapsed; nil → no timeline track under the progress bars.
        var timeline: Double?
    }

    /// Two layout rows (Cursor slot + Grok); Other Models stacks inside the Cursor slot.
    private struct Metrics {
        let rowHeight: CGFloat = 11
        var avatar: CGFloat { rowHeight }
        /// Quota tracks — a bit thicker so usage reads first.
        var trackHeight: CGFloat { 3 }
        /// Time underline — thinner than quota so it reads as period, not usage.
        var timelineHeight: CGFloat { 1.5 }
        var trackGap: CGFloat { 0.5 }
        /// Air between quota group outline and the time bar underneath.
        var timelineGap: CGFloat { 1 }
        /// Squarer than a pill so the group reads as a box, not a stadium.
        var groupCorner: CGFloat { 1.5 }
        var timelineCorner: CGFloat { 0.75 }
        /// Match dual stack outer height so Cursor (2 tracks) and Grok (1) read the same thickness.
        var singleBarHeight: CGFloat { trackHeight * 2 + trackGap }
        var font: NSFont { .monospacedDigitSystemFont(ofSize: 8, weight: .semibold) }
        var height: CGFloat { rowHeight * 2 }

        func quotaHeight(trackCount: Int) -> CGFloat {
            guard trackCount > 0 else { return 0 }
            if trackCount == 1 { return singleBarHeight }
            return CGFloat(trackCount) * trackHeight + CGFloat(trackCount - 1) * trackGap
        }
    }

    /// Track width in points (~44px @2x). Wider = clearer % steps in the menu bar.
    private static let barWidth: CGFloat = 28
    private static let gap: CGFloat = 4

    /// Avatars/text use `foreground`; bars use `row.barColors` (nil → `foreground`).
    static func image(
        rows: [Row],
        showAvatars: Bool,
        showPercent: Bool,
        showRemaining: Bool,
        foreground ink: NSColor
    ) -> NSImage {
        precondition(rows.count == 2, "BarIcon expects Cursor + Grok layout rows")
        let m = Metrics()
        let percents = rows.map(percentLabel)
        let remainings = rows.map { $0.remaining ?? "—" }
        let avatarCol = showAvatars ? m.avatar + gap : 0
        let percentWidth = showPercent ? textWidth(percents, font: m.font) : 0
        let remainingWidth = showRemaining ? textWidth(remainings, font: m.font) : 0
        let percentX = avatarCol + barWidth + gap
        let remainingX = showPercent ? percentX + percentWidth + gap : percentX
        var width = avatarCol + barWidth
        if showPercent { width += gap + percentWidth }
        if showRemaining { width += gap + remainingWidth }

        let image = NSImage(size: NSSize(width: width, height: m.height), flipped: true) { _ in
            for (index, row) in rows.enumerated() {
                let midY = (CGFloat(index) + 0.5) * m.rowHeight
                if showAvatars {
                    drawAvatar(
                        row.avatar,
                        in: NSRect(x: 0, y: midY - m.avatar / 2, width: m.avatar, height: m.avatar),
                        ink: row.avatarColor ?? ink
                    )
                }
                drawBars(row: row, metrics: m, midY: midY, barX: avatarCol, ink: ink)
                if showPercent {
                    drawText(percents[index], x: percentX, midY: midY, font: m.font, ink: ink)
                }
                if showRemaining {
                    drawText(remainings[index], x: remainingX, midY: midY, font: m.font, ink: ink)
                }
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Labels

    /// Single → `23%`; dual → `23/2%` (one `%` at the end). Ceil matches Spending UI.
    static func percentLabel(_ row: Row) -> String {
        let parts = row.fills.map { fill -> String in
            fill.map { String(QuotaPercent.display($0)) } ?? "—"
        }
        guard parts.count > 1 else {
            return parts.first.map { $0 == "—" ? "—" : "\($0)%" } ?? "—"
        }
        return "\(parts.joined(separator: "/"))%"
    }

    // MARK: - Drawing

    private static func drawBars(row: Row, metrics m: Metrics, midY: CGFloat, barX x: CGFloat, ink: NSColor) {
        var fills: [Double?] = Array(row.fills.prefix(2))
        if fills.isEmpty { fills = [nil] }
        let colors: [NSColor] = fills.indices.map { i in
            (i < row.barColors.count ? row.barColors[i] : nil) ?? ink
        }

        let quotaCount = fills.count
        let quotaH = m.quotaHeight(trackCount: quotaCount)
        let hasTimeline = row.timeline != nil
        let totalH = hasTimeline ? quotaH + m.timelineGap + m.timelineHeight : quotaH
        let topY = midY - totalH / 2
        let quotaOuter = NSRect(x: x, y: topY, width: barWidth, height: quotaH)

        if quotaCount == 1 {
            drawBar(
                fill: fills[0],
                color: colors[0],
                ink: ink,
                in: quotaOuter,
                stroke: true,
                ceilFill: true,
                cornerRadius: m.groupCorner,
                emptyTrack: nil
            )
        } else {
            drawQuotaGroup(fills: fills, colors: colors, metrics: m, in: quotaOuter, ink: ink)
        }

        // Time bar sits just under the group outline — not a quota track.
        if let timeline = row.timeline {
            let track = NSRect(
                x: x,
                y: quotaOuter.maxY + m.timelineGap,
                width: barWidth,
                height: m.timelineHeight
            )
            drawBar(
                fill: timeline,
                color: ink,
                ink: ink,
                in: track,
                stroke: false,
                ceilFill: false,
                cornerRadius: m.timelineCorner,
                // Unspent time: white at low opacity; elapsed: solid white; no border.
                emptyTrack: ink.withAlphaComponent(0.22)
            )
        }
    }

    /// Shared outline around Cursor Models + Other Models only (no timeline).
    private static func drawQuotaGroup(
        fills: [Double?],
        colors: [NSColor],
        metrics m: Metrics,
        in outer: NSRect,
        ink: NSColor
    ) {
        let pad = barStroke / 2
        let content = outer.insetBy(dx: pad, dy: pad)
        let count = fills.count
        let gaps = CGFloat(count - 1) * m.trackGap
        let rowH = (content.height - gaps) / CGFloat(count)
        for i in 0..<count {
            let y = content.minY + CGFloat(i) * (rowH + m.trackGap)
            drawBar(
                fill: fills[i],
                color: colors[i],
                ink: ink,
                in: NSRect(x: content.minX, y: y, width: content.width, height: rowH),
                stroke: false,
                ceilFill: true,
                cornerRadius: min(m.groupCorner, rowH / 2),
                emptyTrack: nil
            )
        }
        let outline = NSBezierPath(
            roundedRect: outer,
            xRadius: m.groupCorner,
            yRadius: m.groupCorner
        )
        ink.withAlphaComponent(0.55).setStroke()
        outline.lineWidth = barStroke
        outline.stroke()
        for i in 0..<(count - 1) {
            let sepY = content.minY + CGFloat(i + 1) * rowH + CGFloat(i) * m.trackGap + m.trackGap / 2
            let sep = NSBezierPath()
            sep.move(to: NSPoint(x: content.minX + 1, y: sepY))
            sep.line(to: NSPoint(x: content.maxX - 1, y: sepY))
            ink.withAlphaComponent(0.4).setStroke()
            sep.lineWidth = 0.5
            sep.stroke()
        }
    }

    private static func drawAvatar(_ avatar: Avatar, in box: NSRect, ink: NSColor) {
        let custom = NSImage(named: avatar.rawValue)
        let image = custom ?? fallbackAvatar(avatar, size: box.height)
        // SF Symbols carry internal padding; inset edge-to-edge assets so glyphs match visually.
        let drawBox = custom != nil ? box.insetBy(dx: box.width * 0.08, dy: box.height * 0.08) : box
        // Template assets draw black; tint via source-atop so they follow `ink`.
        image?.draw(in: drawBox)
        if ink != .black {
            ink.setFill()
            box.fill(using: .sourceAtop)
        }
    }

    private static func fallbackAvatar(_ avatar: Avatar, size: CGFloat) -> NSImage? {
        let name: String
        switch avatar {
        case .cursor: name = "cube.fill"
        case .grok: name = "circle.fill"
        }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
    }

    private static let barStroke: CGFloat = 1

    private static func drawBar(
        fill: Double?,
        color: NSColor,
        ink: NSColor,
        in track: NSRect,
        stroke: Bool,
        ceilFill: Bool,
        cornerRadius: CGFloat,
        emptyTrack: NSColor?
    ) {
        let pad = stroke ? barStroke / 2 : 0
        let inner = track.insetBy(dx: pad, dy: pad)
        guard inner.width > 0, inner.height > 0 else { return }
        let innerRadius = min(cornerRadius, inner.height / 2)
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: innerRadius, yRadius: innerRadius)

        // Quota: faint ink wash. Timeline: caller passes white @ low alpha.
        let trackColor = emptyTrack ?? ink.withAlphaComponent(fill == nil ? 0.08 : 0.18)
        trackColor.setFill()
        innerPath.fill()

        // Progress: whole-% like Spending. Timeline: continuous so the clock moves smoothly.
        if let fill {
            let pct = ceilFill ? Double(QuotaPercent.display(fill)) : min(max(fill, 0), 100)
            if pct > 0 {
                let exact = inner.width * CGFloat(pct) / 100
                // Stub at least as wide as the corner diameter so 1% still reads.
                let width = max(exact, min(inner.height, cornerRadius * 2))
                NSGraphicsContext.saveGraphicsState()
                innerPath.addClip()
                color.setFill()
                NSRect(x: inner.minX, y: inner.minY, width: width, height: inner.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // Stroke last so the fill never covers the outline.
        if stroke {
            let r = min(cornerRadius, track.height / 2)
            let outline = NSBezierPath(roundedRect: track, xRadius: r, yRadius: r)
            ink.withAlphaComponent(0.55).setStroke()
            outline.lineWidth = barStroke
            outline.stroke()
        }
    }

    /// Column width = widest string, so nothing clips (`100/100%`, `14m`).
    private static func textWidth(_ texts: [String], font: NSFont) -> CGFloat {
        ceil(texts.map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }.max() ?? 0)
    }

    private static func drawText(_ text: String, x: CGFloat, midY: CGFloat, font: NSFont, ink: NSColor) {
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: ink])
        attributed.draw(at: NSPoint(x: x, y: midY - attributed.size().height / 2))
    }
}
