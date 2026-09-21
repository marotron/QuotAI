import Foundation
import Network
import QuotAICore
import Security

/// SMTP email settings + Keychain password. Send path is a thin adapter (not unit-tested).
enum EmailAlertService {
    static let passwordAccount = "smtp-password"

    struct Config: Equatable {
        var host: String
        var port: Int
        var username: String
        var fromAddress: String
        var toAddress: String
        var useTLS: Bool
    }

    enum SendError: Error, LocalizedError {
        case missingPassword
        case missingConfig
        case smtp(String)

        var errorDescription: String? {
            switch self {
            case .missingPassword: return "SMTP password is not saved in Keychain."
            case .missingConfig: return "Fill in host, from, and to addresses."
            case .smtp(let message): return message
            }
        }
    }

    static func loadPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QuotAIKeychain.service,
            kSecAttrAccount as String: passwordAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func savePassword(_ password: String) throws {
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: QuotAIKeychain.service,
            kSecAttrAccount as String: passwordAccount,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let existing = SecItemCopyMatching(query as CFDictionary, nil)
        if existing == errSecSuccess {
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else { throw KeychainStore.StoreError.unexpectedStatus(status) }
        } else if existing == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainStore.StoreError.unexpectedStatus(status) }
        } else {
            throw KeychainStore.StoreError.unexpectedStatus(existing)
        }
    }

    static func send(config: Config, subject: String, body: String) async throws {
        guard !config.host.isEmpty, !config.fromAddress.isEmpty, !config.toAddress.isEmpty else {
            throw SendError.missingConfig
        }
        guard let password = loadPassword(), !password.isEmpty else {
            throw SendError.missingPassword
        }
        try await SMTPClient.send(
            host: config.host,
            port: config.port,
            username: config.username.isEmpty ? config.fromAddress : config.username,
            password: password,
            from: config.fromAddress,
            to: config.toAddress,
            subject: subject,
            body: body,
            useTLS: config.useTLS
        )
    }
}

/// Minimal SMTP AUTH LOGIN client (implicit TLS on 465, or STARTTLS on 587).
private enum SMTPClient {
    static func send(
        host: String,
        port: Int,
        username: String,
        password: String,
        from: String,
        to: String,
        subject: String,
        body: String,
        useTLS: Bool
    ) async throws {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port)),
            using: useTLS ? .tls : .tcp
        )
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    Task {
                        do {
                            try await runSession(
                                connection: connection,
                                username: username,
                                password: password,
                                from: from,
                                to: to,
                                subject: subject,
                                body: body,
                                useTLS: useTLS
                            )
                            connection.cancel()
                            cont.resume()
                        } catch {
                            connection.cancel()
                            cont.resume(throwing: error)
                        }
                    }
                case .failed(let error):
                    cont.resume(throwing: error)
                case .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
        }
    }

    private static func runSession(
        connection: NWConnection,
        username: String,
        password: String,
        from: String,
        to: String,
        subject: String,
        body: String,
        useTLS: Bool
    ) async throws {
        _ = try await readReply(connection)
        try await sendLine(connection, "EHLO quotai.local")
        _ = try await readReply(connection)

        if !useTLS {
            try await sendLine(connection, "STARTTLS")
            let startTLS = try await readReply(connection)
            guard startTLS.hasPrefix("220") else {
                throw EmailAlertService.SendError.smtp("STARTTLS failed: \(startTLS)")
            }
            // Upgrade not implemented for plain→TLS mid-stream; prefer port 465 with useTLS.
            throw EmailAlertService.SendError.smtp("Use port 465 with TLS enabled (STARTTLS upgrade not supported).")
        }

        try await sendLine(connection, "AUTH LOGIN")
        _ = try await readReply(connection)
        try await sendLine(connection, Data(username.utf8).base64EncodedString())
        _ = try await readReply(connection)
        try await sendLine(connection, Data(password.utf8).base64EncodedString())
        let auth = try await readReply(connection)
        guard auth.hasPrefix("235") else {
            throw EmailAlertService.SendError.smtp("AUTH failed: \(auth)")
        }

        try await sendLine(connection, "MAIL FROM:<\(from)>")
        _ = try await readReply(connection)
        try await sendLine(connection, "RCPT TO:<\(to)>")
        _ = try await readReply(connection)
        try await sendLine(connection, "DATA")
        _ = try await readReply(connection)

        let message = """
        From: \(from)\r
        To: \(to)\r
        Subject: \(subject)\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        \(body)\r
        .\r
        """
        try await sendRaw(connection, message)
        let dataReply = try await readReply(connection)
        guard dataReply.hasPrefix("250") else {
            throw EmailAlertService.SendError.smtp("DATA failed: \(dataReply)")
        }
        try await sendLine(connection, "QUIT")
        _ = try? await readReply(connection)
    }

    private static func sendLine(_ connection: NWConnection, _ line: String) async throws {
        try await sendRaw(connection, line + "\r\n")
    }

    private static func sendRaw(_ connection: NWConnection, _ text: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: Data(text.utf8), completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    private static func readReply(_ connection: NWConnection) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 64_000) { data, _, _, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                let text = String(data: data ?? Data(), encoding: .utf8) ?? ""
                cont.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
