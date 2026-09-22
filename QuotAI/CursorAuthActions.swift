import AppKit

/// Shared prompts for Cursor token / session actions (Settings).
enum CursorAuthActions {
    @MainActor
    static func promptPasteToken(into store: QuotaStore) {
        let alert = NSAlert()
        alert.messageText = "Paste Cursor access token"
        alert.informativeText = "Optional refresh token on the second line. Tokens stay in Keychain only."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 64))
        field.placeholderString = "accessToken\nrefreshToken"
        alert.accessoryView = field
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let lines = field.stringValue
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let access = lines.first else { return }
        store.pasteAccessToken(access, refreshToken: lines.count > 1 ? lines[1] : nil)
    }
}
