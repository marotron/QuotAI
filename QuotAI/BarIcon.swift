import AppKit

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
        let rowHeight: CGFloat = 10
        var avatar: CGFloat { rowHeight }
        var singleBarHeight: CGFloat { 4 }
        var dualBarHeight: CGFloat { 2 }
        var dualGap: CGFloat { 1 }
        var font: NSFont { .monospacedDigitSystemFont(ofSize: 8, weight: .semibold) }
        var height: CGFloat { rowHeight * 2 }
    }

    private static let barWidth: CGFloat = 22
    private static let gap: CGFloat = 4

    /// Avatars/text use `foreground`; bars use `row.barColors` (nil → `foreground`).
    static func image(rows: [Row], showPercent: Bool, showRemaining: Bool, foreground ink: NSColor) -> NSImage {
        precondition(rows.count == 2, "BarIcon expects Cursor + Grok layout rows")
        let m = Metrics()
        let percents = rows.map(percentLabel)
        let remainings = rows.map { $0.remaining ?? "—" }
        let percentWidth = showPercent ? textWidth(percents, font: m.font) : 0
        let remainingWidth = showRemaining ? textWidth(remainings, font: m.font) : 0
        let percentX = m.avatar + gap + barWidth + gap
        let remainingX = showPercent ? percentX + percentWidth + gap : percentX
        var width = m.avatar + gap + barWidth
        if showPercent { width += gap + percentWidth }
        if showRemaining { width += gap + remainingWidth }

        let image = NSImage(size: NSSize(width: width, height: m.height), flipped: true) { _ in
            for (index, row) in rows.enumerated() {
                let midY = (CGFloat(index) + 0.5) * m.rowHeight
                drawAvatar(row.avatar, in: NSRect(x: 0, y: midY - m.avatar / 2, width: m.avatar, height: m.avatar), ink: ink)
                drawBars(row: row, metrics: m, midY: midY, ink: ink)
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

    /// Single → `23%`; dual → `23/2%` (one `%` at the end).
    static func percentLabel(_ row: Row) -> String {
        let parts = row.fills.map { fill -> String in
            fill.map { String(format: "%.0f", $0) } ?? "—"
        }
        guard parts.count > 1 else {
            return parts.first.map { $0 == "—" ? "—" : "\($0)%" } ?? "—"
        }
        return "\(parts.joined(separator: "/"))%"
    }

    // MARK: - Drawing

    private static func drawBars(row: Row, metrics m: Metrics, midY: CGFloat, ink: NSColor) {
        let x = m.avatar + gap
        if row.fills.count <= 1 {
            let fill = row.fills.first ?? nil
            let color = (row.barColors.first ?? nil) ?? ink
            drawBar(
                fill: fill,
                color: color,
                in: NSRect(x: x, y: midY - m.singleBarHeight / 2, width: barWidth, height: m.singleBarHeight)
            )
            return
        }
        let stack = m.dualBarHeight * 2 + m.dualGap
        let topY = midY - stack / 2
        for (i, fill) in row.fills.prefix(2).enumerated() {
            let color = (i < row.barColors.count ? row.barColors[i] : nil) ?? ink
            let y = topY + CGFloat(i) * (m.dualBarHeight + m.dualGap)
            drawBar(
                fill: fill,
                color: color,
                in: NSRect(x: x, y: y, width: barWidth, height: m.dualBarHeight)
            )
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

    private static func drawBar(fill: Double?, color: NSColor, in track: NSRect) {
        let radius = track.height / 2
        color.withAlphaComponent(fill == nil ? 0.15 : 0.3).setFill()
        NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()
        guard let fill else { return }
        var filled = track
        filled.size.width = max(track.height, track.width * CGFloat(min(100, max(0, fill)) / 100))
        color.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
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
