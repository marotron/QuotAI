import SwiftUI
import QuotAICore

/// Circular knob for an integer percent within a closed range.
/// Drag up to increase, drag down to decrease (from the value at press).
struct PercentDial: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var tint: Color = .accentColor
    var size: CGFloat = 36
    /// When set, timeline dials append `elapsed · left` while dragging.
    var periodLength: TimeInterval? = nil
    /// “Full quota before” / “Under alerts after” — show duration split in the drag tip.
    var showsTimelineTip: Bool = false

    /// Bottom gap; track runs the remaining 270°.
    private let trackFraction = 0.75
    /// Vertical pixels per one percent step.
    private let pixelsPerStep: CGFloat = 4

    @State private var dragOriginValue: Int?
    @State private var isDragging = false

    private var trackWidth: CGFloat { max(2.5, size * 0.08) }

    private var fraction: Double {
        let span = Double(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return min(max(Double(value - range.lowerBound) / span, 0), 1)
    }

    private var tipText: String {
        if showsTimelineTip, let periodLength, periodLength > 0 {
            return "\(value)% · \(PeriodDuration.dialTimelineTip(dialPct: value, periodLength: periodLength))"
        }
        return "\(value)%"
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
            .overlay(alignment: .top) {
                if isDragging {
                    Text(tipText)
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .fixedSize()
                        .offset(y: -36)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
            }
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
        .zIndex(isDragging ? 1 : 0)
    }

    private var verticalDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if dragOriginValue == nil {
                    dragOriginValue = value
                    isDragging = true
                }
                let origin = dragOriginValue ?? value
                // translation.height: negative = finger moved up → increase.
                let delta = Int((-drag.translation.height / pixelsPerStep).rounded())
                value = min(max(origin + delta, range.lowerBound), range.upperBound)
            }
            .onEnded { _ in
                dragOriginValue = nil
                isDragging = false
            }
    }
}
