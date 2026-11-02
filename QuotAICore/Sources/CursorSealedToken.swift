import CommonCrypto
import Foundation

/// Cursor 3.27+ seals `cursorAuth/accessToken` / `refreshToken` when
/// `cursor.storage.authTokenEncryptionAtRest` is on. Cell shape:
/// `cursor-safe-storage:v1:` + standard base64 of an Electron safeStorage `v10`
/// blob (AES-128-CBC, 16-space IV, PBKDF2-HMAC-SHA1 over Keychain password,
/// salt `saltysalt`, 1003 rounds).
public enum CursorSealedToken {
    public static let prefix = "cursor-safe-storage:v1:"

    public static func isSealed(_ value: String) -> Bool {
        value.hasPrefix(prefix)
    }

    /// JWT inside a sealed cell, or nil when the password does not open it /
    /// plaintext is not a JWT (wrong key can still PKCS7-unpad to garbage).
    public static func open(stored: String, password: String) -> String? {
        guard isSealed(stored) else { return nil }
        let encoded = String(stored.dropFirst(prefix.count))
        guard let encrypted = Data(base64Encoded: encoded),
              let key = try? deriveKey(password: password),
              let plain = try? decrypt(encrypted, key: key),
              let token = String(data: plain, encoding: .utf8),
              isJWT(token)
        else {
            return nil
        }
        return token
    }

    /// Seal a token the same way Cursor writes the cell (for tests / write-back).
    static func seal(token: String, password: String) throws -> String {
        let key = try deriveKey(password: password)
        let encrypted = try encrypt(Data(token.utf8), key: key)
        return prefix + encrypted.base64EncodedString()
    }

    private static func isJWT(_ token: String) -> Bool {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty }) else { return false }
        var mid = String(parts[1])
        let pad = (4 - mid.count % 4) % 4
        if pad > 0 { mid += String(repeating: "=", count: pad) }
        mid = mid.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let data = Data(base64Encoded: mid),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else { return false }
        return true
    }

    private static func deriveKey(password: String) throws -> Data {
        let passwordData = Data(password.utf8)
        let salt = Data("saltysalt".utf8)
        var key = Data(count: kCCKeySizeAES128)
        let keyCount = key.count
        let result = key.withUnsafeMutableBytes { keyBytes in
            passwordData.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1),
                        1003,
                        keyBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyCount
                    )
                }
            }
        }
        guard result == kCCSuccess else { throw SealedTokenError.invalidKey }
        return key
    }

    private static func decrypt(_ encrypted: Data, key: Data) throws -> Data {
        guard encrypted.count > 3,
              encrypted.prefix(3) == Data("v10".utf8),
              key.count == kCCKeySizeAES128
        else {
            throw SealedTokenError.invalidCiphertext
        }
        return try crypt(CCOperation(kCCDecrypt), data: encrypted.dropFirst(3), key: key)
    }

    private static func encrypt(_ plaintext: Data, key: Data) throws -> Data {
        let encrypted = try crypt(CCOperation(kCCEncrypt), data: plaintext, key: key)
        return Data("v10".utf8) + encrypted
    }

    private static func crypt(_ operation: CCOperation, data: any DataProtocol, key: Data) throws -> Data {
        let input = Data(data)
        let iv = Data(repeating: 0x20, count: kCCBlockSizeAES128)
        var output = Data(count: input.count + kCCBlockSizeAES128)
        var outputLength = 0
        let outputCapacity = output.count
        let status = output.withUnsafeMutableBytes { outputBytes in
            input.withUnsafeBytes { inputBytes in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(
                            operation,
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            key.count,
                            ivBytes.baseAddress,
                            inputBytes.baseAddress,
                            input.count,
                            outputBytes.baseAddress,
                            outputCapacity,
                            &outputLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw SealedTokenError.cryptFailed(status) }
        output.count = outputLength
        return output
    }
}

enum SealedTokenError: Error {
    case invalidKey
    case invalidCiphertext
    case cryptFailed(CCCryptorStatus)
}
