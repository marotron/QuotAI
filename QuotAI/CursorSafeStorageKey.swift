import Foundation
import Security

/// Electron safeStorage password Cursor keeps for sealed editor tokens.
enum CursorSafeStorageKey {
    static let service = "Cursor Safe Storage"
    static let account = "Cursor Key"

    /// Keychain password used to open `cursor-safe-storage:v1:` cells, or nil if missing/denied.
    static func readPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data,
              let password = String(data: data, encoding: .utf8), !password.isEmpty
        else {
            return nil
        }
        return password
    }
}
