import AppKit
import QuotAICore

/// Multi-row menu bar glyph: avatar · bar(s) · percent · time to reset.
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
    }

    /// Two layout rows (Cursor slot + Grok); Other Models stacks inside the Cursor slot.
    private struct Metrics {
        let rowHeight: CGFloat = 11
        var avatar: CGFloat { rowHeight }
        var dualBarHeight: CGFloat { 3 }
        var dualGap: CGFloat { 1 }
        /// Match dual stack outer height so Cursor (2 tracks) and Grok (1) read the same thickness.
        var singleBarHeight: CGFloat { dualBarHeight * 2 + dualGap }
        var font: NSFont { .monospacedDigitSystemFont(ofSize: 8, weight: .semibold) }
        var height: CGFloat { rowHeight * 2 }
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
                    drawAvatar(row.avatar, in: NSRect(x: 0, y: midY - m.avatar / 2, width: m.avatar, height: m.avatar), ink: ink)
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
        if row.fills.count <= 1 {
            let fill = row.fills.first ?? nil
            let color = (row.barColors.first ?? nil) ?? ink
            drawBar(
                fill: fill,
                color: color,
                ink: ink,
                in: NSRect(x: x, y: midY - m.singleBarHeight / 2, width: barWidth, height: m.singleBarHeight),
                stroke: true
            )
            return
        }
        // One shared outline for the Cursor stack — avoids a double border in the gap.
        let stack = m.dualBarHeight * 2 + m.dualGap
        let outer = NSRect(x: x, y: midY - stack / 2, width: barWidth, height: stack)
        let pad = barStroke / 2
        let content = outer.insetBy(dx: pad, dy: pad)
        let rowH = (content.height - m.dualGap) / 2
        for (i, fill) in row.fills.prefix(2).enumerated() {
            let color = (i < row.barColors.count ? row.barColors[i] : nil) ?? ink
            let y = content.minY + CGFloat(i) * (rowH + m.dualGap)
            drawBar(
                fill: fill,
                color: color,
                ink: ink,
                in: NSRect(x: content.minX, y: y, width: content.width, height: rowH),
                stroke: false
            )
        }
        let radius = outer.height / 2
        let outline = NSBezierPath(roundedRect: outer, xRadius: min(radius, m.dualBarHeight), yRadius: min(radius, m.dualBarHeight))
        ink.withAlphaComponent(0.55).setStroke()
        outline.lineWidth = barStroke
        outline.stroke()
        // Single hairline between the two fills.
        let sepY = content.minY + rowH + m.dualGap / 2
        let sep = NSBezierPath()
        sep.move(to: NSPoint(x: content.minX + 1, y: sepY))
        sep.line(to: NSPoint(x: content.maxX - 1, y: sepY))
        ink.withAlphaComponent(0.4).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()
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

    private static func drawBar(fill: Double?, color: NSColor, ink: NSColor, in track: NSRect, stroke: Bool) {
        let pad = stroke ? barStroke / 2 : 0
        let inner = track.insetBy(dx: pad, dy: pad)
        guard inner.width > 0, inner.height > 0 else { return }
        let innerRadius = inner.height / 2
        let innerPath = NSBezierPath(roundedRect: inner, xRadius: innerRadius, yRadius: innerRadius)

        // Light tint of the pace color for the empty track.
        color.withAlphaComponent(fill == nil ? 0.12 : 0.28).setFill()
        innerPath.fill()

        // Same whole-% as the label (Spending UI). 0% → empty track; 1% → visible stub pill.
        if let fill {
            let pct = QuotaPercent.display(fill)
            if pct > 0 {
                let exact = inner.width * CGFloat(pct) / 100
                let width = max(exact, inner.height) // circle stub so 1% reads like Spending
                NSGraphicsContext.saveGraphicsState()
                innerPath.addClip()
                color.setFill()
                NSRect(x: inner.minX, y: inner.minY, width: width, height: inner.height).fill()
                NSGraphicsContext.restoreGraphicsState()
            }
        }

        // Stroke last so the fill never covers the outline.
        if stroke {
            let outerRadius = track.height / 2
            let outline = NSBezierPath(roundedRect: track, xRadius: outerRadius, yRadius: outerRadius)
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
