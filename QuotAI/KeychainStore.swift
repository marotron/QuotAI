import Foundation
import QuotAICore
import Security

enum KeychainStore {
    enum StoreError: Error {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    static func load() throws -> QuotAIKeychain.Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QuotAIKeychain.service,
            kSecAttrAccount as String: QuotAIKeychain.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw StoreError.unexpectedStatus(status)
        }
        do {
            return try JSONDecoder().decode(QuotAIKeychain.Credentials.self, from: data)
        } catch {
            throw StoreError.invalidData
        }
    }

    static func save(_ credentials: QuotAIKeychain.Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QuotAIKeychain.service,
            kSecAttrAccount as String: QuotAIKeychain.account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let existing = SecItemCopyMatching(query as CFDictionary, nil)
        if existing == errSecSuccess {
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
        } else if existing == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw StoreError.unexpectedStatus(status) }
        } else {
            throw StoreError.unexpectedStatus(existing)
        }
    }

    static func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QuotAIKeychain.service,
            kSecAttrAccount as String: QuotAIKeychain.account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.unexpectedStatus(status)
        }
    }
}
