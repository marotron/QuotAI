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
        /// Pull percent glyphs together. Time-to-reset labels stay at the font's own spacing.
        let percentKern: CGFloat = -0.8
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
        let percentWidth = showPercent ? textWidth(percents, font: m.font, percentKern: m.percentKern) : 0
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
                    drawText(percents[index], x: percentX, midY: midY, font: m.font, ink: ink, percentKern: m.percentKern)
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

    /// Single → `23%`; dual → `23/2%` (one `%` at the end). Half and above rounds up.
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
        // Inset by half the quota stroke on each side so left/right match the
        // inner fill edge (timeline has no border of its own).
        if let timeline = row.timeline {
            let pad = barStroke / 2
            let track = NSRect(
                x: x + pad,
                y: quotaOuter.maxY + m.timelineGap,
                width: barWidth - barStroke,
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

    /// Body takes `ink`. White holes (Cursor triangle, Grok eyes) are not painted, so they stay clear.
    static func drawAvatar(_ avatar: Avatar, in box: NSRect, ink: NSColor) {
        if let parts = cutouts[avatar] {
            let fitted = aspectFit(parts.aspect, in: box)
            tinted(parts.body, ink, pointSize: fitted.size)?.draw(
                in: fitted, from: .zero, operation: .sourceOver, fraction: 1
            )
            return
        }
        guard let image = fallbackAvatar(avatar, size: box.height) else { return }
        let painted = NSImage(size: box.size, flipped: false) { rect in
            image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            if ink != .black {
                ink.setFill()
                rect.fill(using: .sourceAtop)
            }
            return true
        }
        painted.isTemplate = false
        painted.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1)
    }

    /// Black body mask. `hole` is the white (triangle, eyes); it is kept for the split and not drawn.
    private struct Cutout {
        var body: NSImage
        var hole: NSImage
        var aspect: CGFloat
    }

    private static let cutouts: [Avatar: Cutout] = {
        var found: [Avatar: Cutout] = [:]
        for avatar in [Avatar.cursor, .grok] {
            if let cutout = loadCutout(named: avatar.rawValue) {
                found[avatar] = cutout
            }
        }
        return found
    }()

    private static func loadCutout(named name: String) -> Cutout? {
        guard let image = NSImage(named: name),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let src = rep.bitmapData else { return nil }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        let spp = rep.samplesPerPixel
        let bpr = rep.bytesPerRow
        // Asset catalog TIFF is often gray+alpha (spp 2), not RGB.
        guard w > 0, h > 0, spp == 1 || spp == 2 || spp >= 3 else { return nil }

        func sample(x: Int, y: Int) -> (lum: Int, a: Int) {
            let s = y * bpr + x * spp
            if spp == 2 { return (Int(src[s]), Int(src[s + 1])) }
            if spp == 1 { return (Int(src[s]), 255) }
            let r = Int(src[s]), g = Int(src[s + 1]), b = Int(src[s + 2])
            let a = spp >= 4 ? Int(src[s + 3]) : 255
            return ((r + g + b) / 3, a)
        }

        func mask(dark: Bool) -> NSImage? {
            guard let out = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: w,
                pixelsHigh: h,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: w * 4,
                bitsPerPixel: 32
            ), let dst = out.bitmapData else { return nil }
            var hits = 0
            for y in 0..<h {
                for x in 0..<w {
                    let (lum, a) = sample(x: x, y: y)
                    let d = y * w * 4 + x * 4
                    let take = a > 8 && (dark ? lum < 128 : lum >= 128)
                    if take {
                        dst[d] = 255
                        dst[d + 1] = 255
                        dst[d + 2] = 255
                        dst[d + 3] = UInt8(a)
                        hits += 1
                    } else {
                        dst[d] = 0
                        dst[d + 1] = 0
                        dst[d + 2] = 0
                        dst[d + 3] = 0
                    }
                }
            }
            guard hits > 0 else { return nil }
            let img = NSImage(size: NSSize(width: w, height: h))
            img.addRepresentation(out)
            img.isTemplate = false
            return img
        }

        guard let body = mask(dark: true) else { return nil }
        let hole = mask(dark: false)
        return Cutout(body: body, hole: hole ?? NSImage(), aspect: CGFloat(w) / CGFloat(h))
    }

    /// Tint offscreen. A drawing-handler image nested inside the menu-bar image drops the glyph.
    private static func tinted(_ mask: NSImage, _ color: NSColor, pointSize: NSSize) -> NSImage? {
        guard pointSize.width > 0, pointSize.height > 0 else { return nil }
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let pw = max(1, Int((pointSize.width * scale).rounded(.up)))
        let ph = max(1, Int((pointSize.height * scale).rounded(.up)))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pw,
            pixelsHigh: ph,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pw * 4,
            bitsPerPixel: 32
        ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        // Bitmap context is in pixels. Drawing in points only fills a corner, then
        // `rep.size` scales that corner down again — the mark becomes a dot.
        // The menu-bar image is flipped, which turns this bitmap upside down, so
        // draw the mask the other way up and the bar shows it upright.
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = ctx
        ctx.cgContext.translateBy(x: 0, y: CGFloat(ph))
        ctx.cgContext.scaleBy(x: 1, y: -1)
        let canvas = NSRect(x: 0, y: 0, width: CGFloat(pw), height: CGFloat(ph))
        mask.draw(in: canvas, from: .zero, operation: .sourceOver, fraction: 1)
        color.setFill()
        canvas.fill(using: .sourceAtop)
        NSGraphicsContext.current = previous
        rep.size = pointSize
        let image = NSImage(size: pointSize)
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }

    private static func aspectFit(_ aspect: CGFloat, in box: NSRect) -> NSRect {
        guard aspect > 0, box.width > 0, box.height > 0 else { return box }
        if aspect > box.width / box.height {
            let h = box.width / aspect
            return NSRect(x: box.minX, y: box.midY - h / 2, width: box.width, height: h)
        }
        let w = box.height * aspect
        return NSRect(x: box.midX - w / 2, y: box.minY, width: w, height: box.height)
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

        // Progress: whole % (half-up). Timeline: continuous so the clock moves smoothly.
        // Percent of inner width so stroked quota and inset timeline share one scale —
        // avoid a height-based min stub (it made early-period used look ~2× elapsed).
        if let fill {
            let pct = ceilFill ? Double(QuotaPercent.display(fill)) : min(max(fill, 0), 100)
            if pct > 0 {
                let exact = inner.width * CGFloat(pct) / 100
                // One point floor so sub-percent still paints a pixel.
                let width = max(exact, 1)
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
    private static func textWidth(_ texts: [String], font: NSFont, percentKern: CGFloat = 0) -> CGFloat {
        ceil(texts.map { text in
            NSAttributedString(string: text, attributes: [
                .font: font,
                .kern: text.contains("%") ? percentKern : 0,
            ]).size().width
        }.max() ?? 0)
    }

    private static func drawText(
        _ text: String,
        x: CGFloat,
        midY: CGFloat,
        font: NSFont,
        ink: NSColor,
        percentKern: CGFloat = 0
    ) {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: ink,
            .kern: text.contains("%") ? percentKern : 0,
        ])
        attributed.draw(at: NSPoint(x: x, y: midY - attributed.size().height / 2))
    }
}
