import QuotAICore
import SwiftUI

/// Ago chip + inverse-pie / refresh glyph. Click refreshes that family.
struct FreshnessBadgeView: View {
    let lastAt: Date
    let now: Date
    let interval: TimeInterval
    let isSpinning: Bool
    let accessibilityName: String
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.colorScheme) private var colorScheme

    private var age: TimeInterval { max(0, now.timeIntervalSince(lastAt)) }
    private var tint: RefreshFreshness.Tint { RefreshFreshness.tint(age: age) }
    private var fresh: Color { Self.color(for: tint) }
    private var elapsed: Double {
        RefreshFreshness.elapsedFraction(age: age, interval: interval)
    }
    private var showRefresh: Bool { hovering || isSpinning }

    var body: some View {
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
        .onHover { hovering = $0 }
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

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(fresh)
                .scaleEffect(0.8)
                .frame(width: 12, height: 12)
                .opacity(showRefresh ? 1 : 0)
                // Rest pose −30° CCW; spin adds a full turn from there.
                .rotationEffect(.degrees(-60 + (isSpinning ? 360 : 0)))
                .animation(
                    isSpinning
                        ? .linear(duration: 0.7).repeatForever(autoreverses: false)
                        : .default,
                    value: isSpinning
                )
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
