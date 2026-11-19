import QuotAICore
import SwiftUI
import AppKit
import QuartzCore

/// Ago chip + inverse-pie / refresh glyph. Click refreshes that family.
struct FreshnessBadgeView: View {
    let lastAt: Date
    let now: Date
    let interval: TimeInterval
    let isSpinning: Bool
    let accessibilityName: String
    var compact: Bool = false
    /// Last refresh attempt failed — compact badge uses amber warning chrome.
    var refreshFailed: Bool = false
    let action: () -> Void

    @State private var hovering = false
    @State private var visualSpinning = false
    @State private var suppressHoverAfterRefresh = false
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var age: TimeInterval { max(0, now.timeIntervalSince(lastAt)) }
    private var tint: RefreshFreshness.Tint { RefreshFreshness.tint(age: age) }
    private var fresh: Color { Self.color(for: tint) }
    private var elapsed: Double {
        RefreshFreshness.elapsedFraction(age: age, interval: interval)
    }
    private var showRefresh: Bool {
        visualSpinning || (!suppressHoverAfterRefresh && (hovering || (compact && focused)))
    }

    @ViewBuilder
    var body: some View {
        if compact {
            compactBadge
        } else {
            standardBadge
        }
    }

    private var compactBadge: some View {
        Button {
            guard !isSpinning else { return }
            action()
        } label: {
            ZStack {
                Text(compactAge)
                    .font(.system(size: 9, weight: .medium))
                    .opacity(showRefresh ? 0 : 1)
                    .offset(y: showRefresh ? 16 : 0)
                RefreshArrow(isSpinning: visualSpinning, color: showRefresh ? .white : .secondary)
                    .opacity(showRefresh ? 1 : 0)
                    .offset(y: showRefresh ? 0 : -16)
            }
            .frame(width: 27, height: 16)
            .clipped()
            .foregroundStyle(showRefresh ? Color.white : (refreshFailed ? Self.warningAmber(colorScheme) : Color.secondary))
            .background(RoundedRectangle(cornerRadius: 4).fill(
                showRefresh
                    ? Color(red: 0x0a / 255, green: 0x82 / 255, blue: 1)
                    : (refreshFailed ? Self.warningFill : Color.primary.opacity(0.08))))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: showRefresh)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onHover { active in
            hovering = active
            if active { suppressHoverAfterRefresh = false }
        }
        .onChange(of: focused) { _, active in
            if active { suppressHoverAfterRefresh = false }
        }
        .task(id: isSpinning) { await updateVisualSpin() }
        .help(refreshFailed
              ? "Refresh \(accessibilityName) · last attempt failed · check connection"
              : "Refresh \(accessibilityName)")
        .accessibilityLabel(refreshFailed
            ? "Refresh \(accessibilityName), refresh failed"
            : "Refresh \(accessibilityName), \(MenuBarWindowPanel.relativeAgo(from: lastAt, to: now))")
        .accessibilityHint(isSpinning ? "Refresh in progress" : "Refresh this provider")
    }

    static func warningAmber(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0xff / 255, green: 0xc2 / 255, blue: 0x5c / 255)
            : Color(red: 0xa5 / 255, green: 0x6b / 255, blue: 0)
    }

    static var warningFill: Color {
        Color(red: 0xff / 255, green: 0x9f / 255, blue: 0x0a / 255).opacity(0.133)
    }

    @MainActor
    private func updateVisualSpin() async {
        if isSpinning {
            visualSpinning = true
            suppressHoverAfterRefresh = false
        } else if visualSpinning {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            suppressHoverAfterRefresh = true
            visualSpinning = false
        }
    }

    private var compactAge: String {
        let value = MenuBarWindowPanel.relativeAgo(from: lastAt, to: now)
        return value == "just now" ? "now" : value.replacingOccurrences(of: " ago", with: "")
    }

    private var standardBadge: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                // fixedSize — the status row squeezes flexible text first; the
                // ago label must never truncate ("just…").
                Text(MenuBarWindowPanel.relativeAgo(from: lastAt, to: now))
                    .fixedSize()
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(fresh)
                glyph
            }
            .padding(.leading, 5)
            .padding(.trailing, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(fresh.opacity(hovering || isSpinning ? 0.22 : 0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(fresh.opacity(hovering || isSpinning ? 0.48 : 0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSpinning)
        .opacity(isSpinning ? 0.85 : 1)
        .onHover { active in
            hovering = active
            if active { suppressHoverAfterRefresh = false }
        }
        .task(id: isSpinning) { await updateVisualSpin() }
        .padding(.leading, 4)
        .padding(.trailing, 1)
        .help("Refresh \(accessibilityName)")
        .accessibilityLabel(
            "Refresh \(accessibilityName), \(MenuBarWindowPanel.relativeAgo(from: lastAt, to: now))"
        )
    }

    private var glyph: some View {
        ZStack {
            Circle()
                .fill(fresh.opacity(0.55))
                .frame(width: 8.5, height: 8.5)
                .overlay {
                    InversePieBiteShape(elapsed: elapsed)
                        .fill(biteFill)
                        .frame(width: 12, height: 12)
                }
                .opacity(showRefresh ? 0 : 1)

            RefreshArrow(isSpinning: visualSpinning, color: fresh)
                .foregroundStyle(fresh)
                .scaleEffect(0.8)
                .frame(width: 12, height: 12)
                .opacity(showRefresh ? 1 : 0)
                .rotationEffect(.degrees(-60))
        }
        .frame(width: 12, height: 12)
        .animation(.easeInOut(duration: 0.08), value: showRefresh)
    }

    private var biteFill: Color {
        colorScheme == .dark
            ? Color(red: 0x2c / 255, green: 0x2c / 255, blue: 0x2e / 255).opacity(0.92)
            : Color(red: 0xf5 / 255, green: 0xf5 / 255, blue: 0xf7 / 255).opacity(0.92)
    }

    static func color(for tint: RefreshFreshness.Tint) -> Color {
        switch tint {
        case .overdue:
            return Color(red: 0xdc / 255, green: 0x26 / 255, blue: 0x26 / 255)
        case .ramp(let t):
            let u = max(0, min(1, t))
            // sRGB lerp green #16a34a → amber #f59e0b
            return Color(
                red: 0x16 / 255 + (0xf5 / 255 - 0x16 / 255) * u,
                green: 0xa3 / 255 + (0x9e / 255 - 0xa3 / 255) * u,
                blue: 0x4a / 255 + (0x0b / 255 - 0x4a / 255) * u
            )
        }
    }
}

/// Core Animation keeps rotation smooth when the main thread handles a refresh update.
struct RefreshArrow: View {
    let isSpinning: Bool
    var color: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RefreshRotation(isSpinning: isSpinning && !reduceMotion, reduceMotion: reduceMotion, color: NSColor(color))
            .frame(width: 11, height: 11)
    }
}

private final class RefreshRotationImage: NSView {
    let arrow = CALayer()
    var rotating = false
    var tint: NSColor?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(arrow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arrow.bounds = CGRect(origin: .zero, size: bounds.size)
        arrow.position = CGPoint(x: bounds.midX, y: bounds.midY)
        arrow.contentsScale = window?.backingScaleFactor ?? 2
        CATransaction.commit()
    }
}

private struct RefreshRotation: NSViewRepresentable {
    let isSpinning: Bool
    let reduceMotion: Bool
    let color: NSColor

    func makeNSView(context: Context) -> RefreshRotationImage {
        RefreshRotationImage()
    }

    func updateNSView(_ view: RefreshRotationImage, context: Context) {
        let layer = view.arrow
        if view.tint != color {
            view.tint = color
            // Match the approved prototype's 16 × 16 SVG path exactly.
            let tinted = NSImage(size: NSSize(width: 11, height: 11), flipped: false) { rect in
                guard let context = NSGraphicsContext.current?.cgContext else { return false }
                context.saveGState()
                context.translateBy(x: rect.minX, y: rect.maxY)
                context.scaleBy(x: rect.width / 16, y: -rect.height / 16)
                context.setStrokeColor(color.cgColor)
                context.setLineWidth(1.4)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                context.addArc(center: CGPoint(x: 8.2857463365, y: 8.0542835776), radius: 5.1,
                               startAngle: -30.0555840477 * .pi / 180,
                               endAngle: 22.4274343791 * .pi / 180, clockwise: true)
                context.move(to: CGPoint(x: 10, y: 5.5))
                context.addLine(to: CGPoint(x: 13.5, y: 5.5))
                context.addLine(to: CGPoint(x: 13.5, y: 2))
                context.strokePath()
                context.restoreGState()
                return true
            }
            var proposed = CGRect(x: 0, y: 0, width: 22, height: 22)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.contents = tinted.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
            CATransaction.commit()
        }
        if reduceMotion {
            layer.removeAnimation(forKey: "refreshRotation")
            view.rotating = false
            return
        }
        guard view.rotating != isSpinning else { return }
        view.rotating = isSpinning
        let current = layer.presentation().map { atan2(Double($0.transform.m12), Double($0.transform.m11)) } ?? 0
        layer.removeAnimation(forKey: "refreshRotation")
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.fromValue = current
        if isSpinning {
            animation.toValue = current - 2 * Double.pi
            animation.duration = 0.8
            animation.repeatCount = .infinity
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
        } else {
            let phase = current > 0 ? current - 2 * Double.pi : current
            animation.fromValue = phase
            animation.toValue = -2 * Double.pi
            animation.duration = 0.35
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        }
        layer.add(animation, forKey: "refreshRotation")
    }
}

// MARK: - Shapes

/// Clockwise wedge from 12-o'clock covering `elapsed` of the disk (the “bite”).
private struct InversePieBiteShape: Shape {
    var elapsed: Double

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = max(0, min(1, elapsed))
        if t <= 0.001 { return Path() }

        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) * (4.25 / 12)
        var path = Path()

        if t >= 0.999 {
            path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            return path
        }

        let sweep = Angle.radians(t * .pi * 2)
        path.move(to: CGPoint(x: cx, y: cy))
        path.addLine(to: CGPoint(x: cx, y: cy - r))
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: r,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90) + sweep,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}
