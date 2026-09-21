import SwiftUI

/// Circular knob for an integer percent within a closed range.
/// Drag up to increase, drag down to decrease (from the value at press).
struct PercentDial: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var tint: Color = .accentColor
    var size: CGFloat = 36

    /// Bottom gap; track runs the remaining 270°.
    private let trackFraction = 0.75
    /// Vertical pixels per one percent step.
    private let pixelsPerStep: CGFloat = 4

    @State private var dragOriginValue: Int?

    private var trackWidth: CGFloat { max(2.5, size * 0.08) }

    private var fraction: Double {
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return min(max(Double(value - range.lowerBound) / span, 0), 1)
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .trim(from: 0, to: trackFraction)
                    .stroke(Color.secondary.opacity(0.25), style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: trackFraction * fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                    .rotationEffect(.degrees(135))

                Text("\(value)%")
                    .font(.system(size: max(9, size * 0.28), weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
            .gesture(verticalDrag)
            .accessibilityLabel(title)
            .accessibilityValue("\(value) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    value = min(value + 1, range.upperBound)
                case .decrement:
                    value = max(value - 1, range.lowerBound)
                @unknown default:
                    break
                }
            }

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(width: size + 28)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: size + 28)
    }

    private var verticalDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if dragOriginValue == nil {
                    dragOriginValue = value
                }
                let origin = dragOriginValue ?? value
                // translation.height: negative = finger moved up → increase.
                let delta = Int((-drag.translation.height / pixelsPerStep).rounded())
                value = min(max(origin + delta, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                dragOriginValue = nil
            }
    }
}
