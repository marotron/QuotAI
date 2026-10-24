#if DEBUG
import AppKit
import SwiftUI

private struct RingIconPreview: View {
    var body: some View {
        VStack(spacing: 16) {
            sample(background: NSColor(white: 0.94, alpha: 1), foreground: .black)
            sample(background: NSColor(white: 0.16, alpha: 1), foreground: .white)
        }
        .padding(20)
    }

    private func sample(background: NSColor, foreground: NSColor) -> some View {
        Image(nsImage: RingIcon.image(
            look: .ringsPerQuota,
            dials: [
                dial(avatar: .cursor, used: 38, elapsed: 52, remaining: "12d"),
                dial(avatar: .cursor, used: 100, elapsed: 74, remaining: "6d"),
                dial(avatar: .grok, used: 7, elapsed: 19, remaining: "2d"),
            ],
            showAvatarsBeside: false,
            showUsedPercent: true,
            showElapsedPercent: false,
            showRemainingBeside: true,
            ringCenter: .icon,
            colorMode: .monochrome,
            onPaceLo: 0.9,
            onPaceHi: 1.1,
            foreground: foreground,
            paceColor: { _ in foreground }
        ))
        .padding(.horizontal, 6)
        .frame(height: 24)
        .background(Color(nsColor: background))
    }

    private func dial(
        avatar: BarIcon.Avatar,
        used: Double,
        elapsed: Double,
        remaining: String
    ) -> RingIcon.Dial {
        RingIcon.Dial(
            avatar: avatar,
            showAvatar: true,
            usedPcts: [used],
            brandColors: [nil],
            elapsedPct: elapsed,
            remaining: remaining,
            displayedUsedIndex: 0
        )
    }
}

#Preview("Three dual-line ring dials") {
    RingIconPreview()
}
#endif
