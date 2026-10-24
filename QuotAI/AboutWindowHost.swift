import AppKit
import SwiftUI

/// Detached About / Changelog windows for the LSUIElement menu-bar app.
@MainActor
final class AboutWindowHost {
    static let shared = AboutWindowHost()

    private var about: NSWindow?
    private var changelog: NSWindow?

    func showAbout() {
        SettingsWindowElevator.show { presentAbout() }
    }

    func showChangelog() {
        SettingsWindowElevator.show { presentChangelog() }
    }

    private func presentAbout() {
        let root = QuotAIAboutView()
        if let about {
            install(root, in: about)
        } else {
            about = makeWindow(
                title: "About QuotAI",
                size: NSSize(width: 400, height: 420),
                resizable: false,
                root: root
            )
        }
        bringForward(about)
    }

    private func presentChangelog() {
        let root = QuotAIChangelogView()
        if let changelog {
            install(root, in: changelog)
        } else {
            changelog = makeWindow(
                title: "QuotAI Changelog",
                size: NSSize(width: 520, height: 560),
                resizable: true,
                root: root
            )
            changelog?.minSize = NSSize(width: 440, height: 360)
        }
        bringForward(changelog)
    }

    private func makeWindow<Content: View>(
        title: String,
        size: NSSize,
        resizable: Bool,
        root: Content
    ) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable {
            style.insert(.resizable)
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        install(root, in: window, contentSize: size)
        window.center()
        return window
    }

    private func install<Content: View>(_ root: Content, in window: NSWindow, contentSize: NSSize? = nil) {
        let size = contentSize ?? window.contentRect(forFrameRect: window.frame).size
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
    }

    private func bringForward(_ window: NSWindow?) {
        guard let window else { return }
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        SettingsWindowElevator.raise()
    }
}
