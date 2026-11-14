import AppKit
import SwiftUI

/// Native text editing plus the alert dials' four-point vertical drag steps.
struct NativeDragNumberField: NSViewRepresentable {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var label: String
    var padded = false
    var onFocus: (Bool) -> Void = { _ in }
    var onDrag: (Bool) -> Void = { _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> DragTextField {
        let field = DragTextField()
        field.delegate = context.coordinator
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.setAccessibilityLabel(label)
        field.stringValue = formatted(value)
        field.onDrag = { [weak coordinator = context.coordinator] delta, started in
            coordinator?.drag(delta: delta, started: started)
        }
        return field
    }

    func updateNSView(_ field: DragTextField, context: Context) {
        context.coordinator.parent = self
        field.setAccessibilityLabel(label)
        if !context.coordinator.editing || context.coordinator.dragging {
            let text = formatted(value)
            if field.stringValue != text { field.stringValue = text }
        }
    }

    private func formatted(_ number: Int) -> String {
        padded ? String(format: "%02d", number) : String(number)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeDragNumberField
        var editing = false
        var dragging = false
        private var origin = 0

        init(_ parent: NativeDragNumberField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            editing = true
            parent.onFocus(true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            editing = false
            if let field = notification.object as? NSTextField {
                if let number = Int(field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    parent.value = min(max(number, parent.range.lowerBound), parent.range.upperBound)
                }
                field.stringValue = parent.formatted(parent.value)
            }
            parent.onFocus(false)
        }

        func drag(delta: Int, started: Bool) -> String? {
            if started && !dragging {
                origin = parent.value
                dragging = true
                parent.onDrag(true)
            }
            guard started else {
                dragging = false
                parent.onDrag(false)
                return nil
            }
            parent.value = min(max(origin + delta, parent.range.lowerBound), parent.range.upperBound)
            return parent.formatted(parent.value)
        }
    }
}

/// Own the mouse-down/drag sequence before the field editor starts text selection.
/// A click focuses and selects the number; vertical movement scrubs its value.
final class DragTextField: NSTextField {
    var onDrag: ((Int, Bool) -> String?)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self, let window = self.window, event.window === window,
                  self.bounds.contains(self.convert(event.locationInWindow, from: nil)) else { return event }
            self.trackNumber(from: event, in: window)
            return nil
        }
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    private func trackNumber(from initial: NSEvent, in window: NSWindow) {
        let start = initial.locationInWindow
        var dragging = false
        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { break }
            let change = event.locationInWindow.y - start.y
            if dragging || abs(change) >= 3 {
                dragging = true
                if let text = onDrag?(Int((change / 4).rounded()), true) {
                    stringValue = text
                    currentEditor()?.string = text
                }
            }
        }
        if dragging {
            _ = onDrag?(0, false)
        } else {
            window.makeFirstResponder(self)
            selectText(nil)
        }
    }
}
