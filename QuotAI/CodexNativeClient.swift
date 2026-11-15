import AppKit
import CryptoKit
import Foundation
import Network
import Security
import QuotAICore

enum CodexServiceError: Error, LocalizedError {
    case message(String)
    case http(String, Int)
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .http(let operation, let status): return "\(operation) failed (HTTP \(status))."
        }
    }
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

private func decodeBase64URL(_ value: String) throws -> Data {
    var encoded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: encoded) else { throw CodexServiceError.message("Invalid token encoding.") }
    return data
}

private func randomValue() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw CodexServiceError.message("Cannot generate secure sign-in values.")
    }
    return base64URL(Data(bytes))
}

private func formData(_ values: [String: String]) -> Data {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return Data(values.sorted { $0.key < $1.key }.map {
        "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
    }.joined(separator: "&").utf8)
}

private final class CodexNoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private final class CodexHTTP {
    private let delegate = CodexNoRedirects()
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }()

    func data(_ request: URLRequest, operation: String) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw CodexServiceError.message("\(operation): no HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Deliberately never include response bodies, requests, headers or tokens.
            throw CodexServiceError.http(operation, http.statusCode)
        }
        guard data.count <= 2_000_000 else { throw CodexServiceError.message("\(operation): response too large.") }
        return data
    }
}

/// A loopback-only, bounded callback listener. Wrong-state requests do not consume the attempt.
private final class CodexLoginCallback: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.marotron.QuotAI.codex-probe-callback")
    private let listener: NWListener
    let port: UInt16
    private var pending: CheckedContinuation<String, Error>?
    private var expectedState = ""
    private var startup: CheckedContinuation<Void, Error>?
    private var receivedRequests = 0
    private var finished = false
    private var timeout: DispatchWorkItem?

    init(port: UInt16) throws {
        self.port = port
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        listener = try NWListener(using: parameters)
    }

    var redirectURI: String { "http://127.0.0.1:\(port)/auth/callback" }

    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startup = continuation
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ready = self.startup
                    self.startup = nil
                    ready?.resume()
                case .failed:
                    let ready = self.startup
                    self.startup = nil
                    ready?.resume(throwing: CodexServiceError.message("Cannot open loopback callback port \(self.port)."))
                    self.complete(.failure(CodexServiceError.message("The sign-in callback listener failed.")))
                default: break
                }
            }
            listener.newConnectionHandler = { connection in
                self.receivedRequests += 1
                guard self.receivedRequests <= 32 else { connection.cancel(); return }
                connection.start(queue: self.queue)
                self.receive(connection, accumulated: Data())
            }
            listener.start(queue: queue)
        }
    }

    func code(state: String, openBrowser: @escaping @Sendable () -> Void) async throws -> String {
        try await withTaskCancellationHandler(operation: {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard !self.finished else { continuation.resume(throwing: CancellationError()); return }
                self.expectedState = state
                self.pending = continuation
                let deadline = DispatchWorkItem {
                    self.complete(.failure(CodexServiceError.message("Codex sign-in timed out after five minutes. Please sign in again.")))
                }
                self.timeout = deadline
                self.queue.asyncAfter(deadline: .now() + 300, execute: deadline)
                openBrowser()
            }
        }
        }, onCancel: { self.stop() })
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, complete, error in
            var bytes = accumulated
            bytes.append(data ?? Data())
            guard bytes.count <= 16_384 else { self.reply(connection, status: "400 Bad Request", text: "Request too large."); return }
            if bytes.range(of: Data("\r\n\r\n".utf8)) != nil {
                self.handle(bytes, connection: connection)
            } else if complete || error != nil {
                connection.cancel()
            } else {
                self.receive(connection, accumulated: bytes)
            }
        }
        queue.asyncAfter(deadline: .now() + 10) { connection.cancel() }
    }

    private func handle(_ request: Data, connection: NWConnection) {
        guard !finished, let text = String(data: request, encoding: .utf8),
              let line = text.components(separatedBy: "\r\n").first else { connection.cancel(); return }
        let parts = line.split(separator: " ")
        guard parts.count == 3, parts[0] == "GET", parts[1].first == "/",
              let url = URLComponents(string: "http://127.0.0.1:\(port)\(parts[1])"),
              url.path == "/auth/callback" else {
            reply(connection, status: "404 Not Found", text: "This listener only accepts the sign-in callback."); return
        }
        let host = text.components(separatedBy: "\r\n").dropFirst().first {
            $0.lowercased().hasPrefix("host:")
        }?.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard host == "127.0.0.1:\(port)" else {
            reply(connection, status: "400 Bad Request", text: "Invalid callback host."); return
        }
        var values: [String: String] = [:]
        for item in url.queryItems ?? [] {
            guard values[item.name] == nil else {
                reply(connection, status: "400 Bad Request", text: "Duplicate callback parameter."); return
            }
            values[item.name] = item.value ?? ""
        }
        guard !expectedState.isEmpty, values["state"] == expectedState else {
            reply(connection, status: "400 Bad Request", text: "Sign-in state did not match. The original attempt is still open."); return
        }
        if values["error"] != nil {
            reply(connection, status: "200 OK", text: "Sign-in was cancelled. You can close this tab.")
            complete(.failure(CodexServiceError.message("Sign-in was declined or cancelled."))); return
        }
        guard let code = values["code"], !code.isEmpty else {
            reply(connection, status: "400 Bad Request", text: "Missing authorization code."); return
        }
        reply(connection, status: "200 OK", text: "QuotAI received the sign-in callback. You can close this tab and return to QuotAI.")
        complete(.success(code))
    }

    private func reply(_ connection: NWConnection, status: String, text: String) {
        let body = Data(text.utf8)
        let headers = "HTTP/1.1 \(status)\r\nContent-Type: text/plain; charset=utf-8\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(headers.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func complete(_ result: Result<String, Error>) {
        guard !finished, let continuation = pending else { return }
        finished = true
        pending = nil
        expectedState = ""
        timeout?.cancel()
        timeout = nil
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
        continuation.resume(with: result)
    }

    func stop() { queue.async {
        self.complete(.failure(CancellationError()))
        self.finished = true
        let ready = self.startup
        self.startup = nil
        ready?.resume(throwing: CancellationError())
        self.listener.stateUpdateHandler = nil
        self.listener.newConnectionHandler = nil
        self.listener.cancel()
    } }
}

/// Use verified ID-token claims for account routing; never accept arbitrary pasted tokens.
private func verifiedClaims(_ token: String, nonce: String?, clientID: String, http: CodexHTTP) async throws -> [String: Any] {
    let segments = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard segments.count == 3,
          let header = try JSONSerialization.jsonObject(with: decodeBase64URL(segments[0])) as? [String: Any],
          header["alg"] as? String == "RS256", let keyID = header["kid"] as? String,
          let claims = try JSONSerialization.jsonObject(with: decodeBase64URL(segments[1])) as? [String: Any]
    else { throw CodexServiceError.message("Unsupported ID token.") }
    let keysData = try await http.data(URLRequest(url: URL(string: "https://auth.openai.com/.well-known/jwks.json")!), operation: "Signing-key read")
    guard let keys = try JSONSerialization.jsonObject(with: keysData) as? [String: Any],
          let key = (keys["keys"] as? [[String: Any]])?.first(where: { $0["kid"] as? String == keyID && $0["kty"] as? String == "RSA" }),
          let n = key["n"] as? String, let e = key["e"] as? String else {
        throw CodexServiceError.message("Cannot find the ID token's signing key.")
    }
    func der(_ tag: UInt8, _ value: Data) -> Data {
        var length = [UInt8]()
        if value.count < 128 { length = [UInt8(value.count)] }
        else {
            var count = value.count
            while count > 0 { length.insert(UInt8(count & 255), at: 0); count >>= 8 }
            length.insert(0x80 | UInt8(length.count), at: 0)
        }
        return Data([tag] + length) + value
    }
    func integer(_ value: Data) -> Data {
        var value = value
        while value.count > 1 && value.first == 0 { value.removeFirst() }
        if let first = value.first, first & 0x80 != 0 { value.insert(0, at: 0) }
        return der(0x02, value)
    }
    let keyData = try der(0x30, integer(decodeBase64URL(n)) + integer(decodeBase64URL(e)))
    guard let rsa = SecKeyCreateWithData(keyData as CFData, [
        kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic
    ] as CFDictionary, nil),
          SecKeyVerifySignature(rsa, .rsaSignatureMessagePKCS1v15SHA256,
              Data("\(segments[0]).\(segments[1])".utf8) as CFData,
              try decodeBase64URL(segments[2]) as CFData, nil)
    else { throw CodexServiceError.message("ID-token signature validation failed.") }
    let audience = (claims["aud"] as? [String]) ?? (claims["aud"] as? String).map { [$0] } ?? []
    guard claims["iss"] as? String == "https://auth.openai.com", audience.contains(clientID),
          (nonce == nil || claims["nonce"] as? String == nonce),
          let expiry = claims["exp"] as? Double, expiry > Date().timeIntervalSince1970,
          let subject = claims["sub"] as? String, !subject.isEmpty else {
        throw CodexServiceError.message("ID-token identity, nonce, audience or expiry validation failed.")
    }
    return claims
}

struct CodexCredentials: Codable, Sendable {
    var accessToken: String
    var refreshToken: String?
    var accountID: String
    var subject: String
    var email: String?
    var expiresAt: Date
}

/// Direct native networking only. No CLI, helper, local credential import or model requests.
final class CodexNativeClient {
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let http = CodexHTTP()

    private struct Tokens: Decodable {
        var access_token: String?
        var id_token: String?
        var refresh_token: String?
        var expires_in: Double?
    }

    func signIn() async throws -> CodexCredentials {
        let verifier = try randomValue(), state = try randomValue(), nonce = try randomValue()
        var callback: CodexLoginCallback?
        for port: UInt16 in [1455, 1457] {
            do {
                let candidate = try CodexLoginCallback(port: port)
                do { try await candidate.start(); callback = candidate; break }
                catch { candidate.stop() }
            } catch { continue }
        }
        guard let callback else {
            throw CodexServiceError.message("Finish any other Codex sign-in and try again; the callback ports are busy.")
        }
        defer { callback.stop() }
        var authorization = URLComponents(string: "https://auth.openai.com/oauth/authorize")!
        authorization.queryItems = [
            "client_id": Self.clientID, "response_type": "code", "redirect_uri": callback.redirectURI,
            "scope": "openid profile email offline_access", "state": state, "nonce": nonce,
            "code_challenge_method": "S256", "code_challenge": base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))),
            "id_token_add_organizations": "true", "codex_cli_simplified_flow": "true", "originator": "quotai"
        ].map { URLQueryItem(name: $0.key, value: $0.value) }
        let authorizationURL = authorization.url!
        let code = try await callback.code(state: state) {
            DispatchQueue.main.async { _ = NSWorkspace.shared.open(authorizationURL) }
        }
        try Task.checkCancellation()
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData([
            "grant_type": "authorization_code", "client_id": Self.clientID, "code": code,
            "redirect_uri": callback.redirectURI, "code_verifier": verifier
        ])
        // A timed-out code exchange may have consumed its code. Never replay it automatically.
        let tokens = try JSONDecoder().decode(Tokens.self, from: await http.data(request, operation: "Codex sign-in"))
        guard let idToken = tokens.id_token, let access = tokens.access_token, !access.isEmpty else {
            throw CodexServiceError.message("Codex sign-in returned incomplete credentials. Please sign in again.")
        }
        let claims = try await verifiedClaims(idToken, nonce: nonce, clientID: Self.clientID, http: http)
        let identity = try accountIdentity(claims)
        return CodexCredentials(accessToken: access, refreshToken: tokens.refresh_token,
            accountID: identity.account, subject: identity.subject, email: claims["email"] as? String,
            expiresAt: expiry(tokens))
    }

    func refresh(_ previous: CodexCredentials) async throws -> CodexCredentials {
        guard let refresh = previous.refreshToken, !refresh.isEmpty else {
            throw CodexServiceError.http("Codex credential refresh", 401)
        }
        var request = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token", "client_id": Self.clientID,
            "refresh_token": refresh, "refresh_reason": "proactive_expiry"
        ])
        let tokens = try JSONDecoder().decode(Tokens.self, from: await http.data(request, operation: "Codex credential refresh"))
        var updated = previous
        if let idToken = tokens.id_token {
            let claims = try await verifiedClaims(idToken, nonce: nil, clientID: Self.clientID, http: http)
            let identity = try accountIdentity(claims)
            guard identity.account == previous.accountID, identity.subject == previous.subject else {
                throw CodexServiceError.message("Codex account changed during credential refresh. Sign in again.")
            }
            updated.email = claims["email"] as? String ?? previous.email
        }
        guard let access = tokens.access_token, !access.isEmpty else {
            throw CodexServiceError.message("Codex did not return a refreshed access credential. Sign in again.")
        }
        updated.accessToken = access
        updated.refreshToken = tokens.refresh_token ?? previous.refreshToken
        updated.expiresAt = expiry(tokens)
        return updated
    }

    func read(_ credentials: CodexCredentials) async throws -> CodexQuotaSnapshot {
        var request = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountID, forHTTPHeaderField: "chatgpt-account-id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        request.setValue("QuotAI/\(version)", forHTTPHeaderField: "User-Agent")
        return try CodexQuotaSnapshot.parse(await http.data(request, operation: "Codex quota read"), expectedAccount: credentials.accountID)
    }

    private func accountIdentity(_ claims: [String: Any]) throws -> (account: String, subject: String) {
        guard let auth = claims["https://api.openai.com/auth"] as? [String: Any],
              auth["chatgpt_account_is_fedramp"] as? Bool != true,
              let account = auth["chatgpt_account_id"] as? String, !account.isEmpty,
              let subject = claims["sub"] as? String, !subject.isEmpty else {
            throw CodexServiceError.message("This Codex account does not expose supported quota routing.")
        }
        return (account, subject)
    }

    private func expiry(_ tokens: Tokens) -> Date {
        if let seconds = tokens.expires_in, seconds.isFinite, seconds > 0, seconds < 31536000 {
            return Date().addingTimeInterval(seconds)
        }
        if let token = tokens.access_token,
           let segment = token.split(separator: ".").dropFirst().first,
           let data = try? decodeBase64URL(String(segment)),
           let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let seconds = claims["exp"] as? Double, seconds.isFinite {
            // Only a refresh scheduling hint. Identity comes exclusively from the verified ID token.
            return Date(timeIntervalSince1970: seconds)
        }
        return Date().addingTimeInterval(300)
    }
}
