// Throwaway feasibility probe: native browser OAuth -> subscription quota GET.
// Credentials exist only in memory. No Codex installation or credential import.
import AppKit
import CryptoKit
import Foundation
import Network
import Security

enum ProbeFailure: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

func base64URL(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
}

func decodeBase64URL(_ value: String) throws -> Data {
    var encoded = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: encoded) else { throw ProbeFailure.message("Invalid token encoding.") }
    return data
}

func randomValue() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 32)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
        throw ProbeFailure.message("Cannot generate secure sign-in values.")
    }
    return base64URL(Data(bytes))
}

func formData(_ values: [String: String]) -> Data {
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
    return Data(values.sorted { $0.key < $1.key }.map {
        "\($0.key.addingPercentEncoding(withAllowedCharacters: allowed)!)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
    }.joined(separator: "&").utf8)
}

final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

final class NativeHTTP {
    private let delegate = NoRedirects()
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
            throw ProbeFailure.message("\(operation): no HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            // Deliberately never include response bodies, requests, headers or tokens.
            throw ProbeFailure.message("\(operation): HTTP \(http.statusCode). No credentials or response body were logged.")
        }
        guard data.count <= 2_000_000 else { throw ProbeFailure.message("\(operation): response too large.") }
        return data
    }
}

/// A loopback-only, bounded callback listener. Wrong-state requests do not consume the attempt.
final class LoginCallback: @unchecked Sendable {
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
                    ready?.resume(throwing: ProbeFailure.message("Cannot open loopback callback port \(self.port)."))
                    self.complete(.failure(ProbeFailure.message("The sign-in callback listener failed.")))
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
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.expectedState = state
                self.pending = continuation
                let deadline = DispatchWorkItem {
                    self.complete(.failure(ProbeFailure.message("Sign-in timed out after five minutes. Run the probe again to retry.")))
                }
                self.timeout = deadline
                self.queue.asyncAfter(deadline: .now() + 300, execute: deadline)
                openBrowser()
            }
        }
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
            complete(.failure(ProbeFailure.message("Sign-in was declined or cancelled."))); return
        }
        guard let code = values["code"], !code.isEmpty else {
            reply(connection, status: "400 Bad Request", text: "Missing authorization code."); return
        }
        reply(connection, status: "200 OK", text: "QuotAI received the sign-in callback. You can close this tab. The native probe is checking quota access.")
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
        listener.cancel()
        continuation.resume(with: result)
    }

    func stop() { queue.async { self.listener.cancel() } }
}

struct TokenReply: Decodable {
    let access_token: String
    let id_token: String
    let refresh_token: String?
}

/// Use verified ID-token claims for account routing; never accept arbitrary pasted tokens.
func verifiedClaims(_ token: String, nonce: String, clientID: String, http: NativeHTTP) async throws -> [String: Any] {
    let segments = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard segments.count == 3,
          let header = try JSONSerialization.jsonObject(with: decodeBase64URL(segments[0])) as? [String: Any],
          header["alg"] as? String == "RS256", let keyID = header["kid"] as? String,
          let claims = try JSONSerialization.jsonObject(with: decodeBase64URL(segments[1])) as? [String: Any]
    else { throw ProbeFailure.message("Unsupported ID token.") }
    let keysData = try await http.data(URLRequest(url: URL(string: "https://auth.openai.com/.well-known/jwks.json")!), operation: "Signing-key read")
    guard let keys = try JSONSerialization.jsonObject(with: keysData) as? [String: Any],
          let key = (keys["keys"] as? [[String: Any]])?.first(where: { $0["kid"] as? String == keyID && $0["kty"] as? String == "RSA" }),
          let n = key["n"] as? String, let e = key["e"] as? String else {
        throw ProbeFailure.message("Cannot find the ID token's signing key.")
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
    else { throw ProbeFailure.message("ID-token signature validation failed.") }
    let audience = (claims["aud"] as? [String]) ?? (claims["aud"] as? String).map { [$0] } ?? []
    guard claims["iss"] as? String == "https://auth.openai.com", audience.contains(clientID),
          claims["nonce"] as? String == nonce,
          let expiry = claims["exp"] as? Double, expiry > Date().timeIntervalSince1970,
          let subject = claims["sub"] as? String, !subject.isEmpty else {
        throw ProbeFailure.message("ID-token identity, nonce, audience or expiry validation failed.")
    }
    return claims
}

/// Whitelisted presentation only: raw response/account identifiers never reach stdout or disk.
func quotaSummary(_ data: Data, expectedAccount: String) throws -> String {
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw ProbeFailure.message("Quota response was not a JSON object.")
    }
    if let returned = root["account_id"] as? String, returned != expectedAccount {
        throw ProbeFailure.message("Quota belongs to a different account. Nothing was displayed.")
    }
    var rows = [String]()
    func appendWindows(_ limit: [String: Any]?, title: String) {
        guard let limit else { return }
        for (name, key) in [("Primary", "primary_window"), ("Secondary", "secondary_window")] {
            guard let window = limit[key] as? [String: Any] else { continue }
            let used = (window["used_percent"] as? Double).flatMap { $0.isFinite && (0...100).contains($0) ? $0 : nil }
            let duration = (window["limit_window_seconds"] as? Double).flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            let reset = (window["reset_at"] as? Double).flatMap { $0.isFinite && $0 > 0 ? Date(timeIntervalSince1970: $0) : nil }
            let usedText = used.map { String(format: "%.2f%% used", $0) } ?? "usage unavailable"
            let durationText = duration.map { String(format: "%.0f-minute window", $0 / 60) } ?? "duration unavailable"
            let resetText = reset.map { ISO8601DateFormatter().string(from: $0) } ?? "unavailable"
            rows.append("\(title) / \(name): \(usedText) · \(durationText) · reset \(resetText)")
        }
    }
    appendWindows(root["rate_limit"] as? [String: Any], title: "Codex")
    for (index, item) in (root["additional_rate_limits"] as? [[String: Any]] ?? []).enumerated() {
        let details = item["details"] as? [String: Any] ?? item
        appendWindows(details["rate_limit"] as? [String: Any], title: "Additional bucket \(index + 1)")
    }
    guard !rows.isEmpty else {
        throw ProbeFailure.message("Quota read succeeded but returned no recognized windows. Raw response was not logged or saved.")
    }
    return rows.joined(separator: "\n")
}

@main
struct NativeCodexProbe {
    // Public native-client identifier from the pinned upstream implementation.
    // This tests the existing Codex OAuth flow; it is not an own-app SIWC registration.
    static let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    static func main() async {
        do {
            if CommandLine.arguments.contains("--offline-check") {
                try offlineCheck()
                return
            }
            if CommandLine.arguments.contains("--callback-check") {
                try await callbackCheck()
                return
            }
            let http = NativeHTTP()
            let verifier = try randomValue(), state = try randomValue(), nonce = try randomValue()
            var callback: LoginCallback?
            for port: UInt16 in [1455, 1457] {
                do {
                    let candidate = try LoginCallback(port: port)
                    do { try await candidate.start(); callback = candidate; break }
                    catch { candidate.stop() }
                } catch { continue }
            }
            guard let callback else { throw ProbeFailure.message("Both supported callback ports are busy. Finish any other Codex sign-in and retry.") }
            defer { callback.stop() }
            var authorization = URLComponents(string: "https://auth.openai.com/oauth/authorize")!
            authorization.queryItems = [
                "client_id": clientID, "response_type": "code", "redirect_uri": callback.redirectURI,
                // Quota access does not require connector read/invoke permissions.
                "scope": "openid profile email offline_access", "state": state, "nonce": nonce,
                "code_challenge_method": "S256", "code_challenge": base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))),
                "id_token_add_organizations": "true", "codex_cli_simplified_flow": "true", "originator": "quotai"
            ].map { URLQueryItem(name: $0.key, value: $0.value) }
            let authorizationURL = authorization.url!
            print("QuotAI native Swift quota probe. No Codex helper or existing credentials are used.")
            print("Opening OpenAI sign-in in your browser. Approve the account you want to test.")
            print("Credentials remain in memory and are discarded when this probe exits.")
            fflush(stdout)
            let code = try await callback.code(state: state) {
                DispatchQueue.main.async { _ = NSWorkspace.shared.open(authorizationURL) }
            }
            print("Callback verified. Exchanging authorization code…")
            var tokenRequest = URLRequest(url: URL(string: "https://auth.openai.com/oauth/token")!)
            tokenRequest.httpMethod = "POST"
            tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            tokenRequest.httpBody = formData([
                "grant_type": "authorization_code", "client_id": clientID, "code": code,
                "redirect_uri": callback.redirectURI, "code_verifier": verifier
            ])
            // Do not retry code exchange: a timed-out request might already have consumed the code.
            let tokens = try JSONDecoder().decode(TokenReply.self, from: await http.data(tokenRequest, operation: "Code exchange"))
            let claims = try await verifiedClaims(tokens.id_token, nonce: nonce, clientID: clientID, http: http)
            guard let auth = claims["https://api.openai.com/auth"] as? [String: Any],
                  let account = auth["chatgpt_account_id"] as? String, !account.isEmpty,
                  auth["chatgpt_account_is_fedramp"] as? Bool != true else {
                throw ProbeFailure.message("No supported account routing in the verified ID token.")
            }
            print("Identity signature verified. Reading subscription quota…")
            var quotaRequest = URLRequest(url: URL(string: "https://chatgpt.com/backend-api/wham/usage")!)
            quotaRequest.setValue("Bearer \(tokens.access_token)", forHTTPHeaderField: "Authorization")
            quotaRequest.setValue(account, forHTTPHeaderField: "chatgpt-account-id")
            quotaRequest.setValue("application/json", forHTTPHeaderField: "Accept")
            quotaRequest.setValue("QuotAI-native-quota-probe/1", forHTTPHeaderField: "User-Agent")
            let result = try await http.data(quotaRequest, operation: "Quota read")
            print(try quotaSummary(result, expectedAccount: account))
            print("SUCCESS: native sign-in and quota read worked without a Codex helper. No credentials were saved.")
        } catch {
            // Avoid NSError descriptions that could include request URLs or server response content.
            let message = (error as? ProbeFailure)?.errorDescription ?? "Native request or decoding failed (details suppressed to protect credentials)."
            print("Probe stopped: \(message)")
            exit(1)
        }
    }

    static func offlineCheck() throws {
        let verifier = try randomValue()
        guard verifier.count == 43, base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))).count == 43 else {
            throw ProbeFailure.message("PKCE shape check failed.")
        }
        let fixture = Data("""
        {"account_id":"test-account","rate_limit":{"primary_window":{"used_percent":42,"limit_window_seconds":18000,"reset_at":2000000000},"secondary_window":null},"additional_rate_limits":[{"metered_feature":"extra","rate_limit":{"primary_window":{"used_percent":0,"limit_window_seconds":604800,"reset_at":2000001000}}}]}
        """.utf8)
        let summary = try quotaSummary(fixture, expectedAccount: "test-account")
        guard summary.contains("42.00%"), summary.contains("0.00%"), !summary.contains("test-account") else {
            throw ProbeFailure.message("Whitelisted quota decoding check failed.")
        }
        do {
            _ = try quotaSummary(fixture, expectedAccount: "different-account")
            throw ProbeFailure.message("Account mismatch was not rejected.")
        } catch ProbeFailure.message(let message) where message.hasPrefix("Quota belongs") {}
        print("Offline checks passed: PKCE generation, quota windows, zero usage, omitted window, account mismatch and redacted output.")
    }

    static func callbackCheck() async throws {
        let callback = try LoginCallback(port: 1457)
        try await callback.start()
        defer { callback.stop() }
        let task = Task { try await callback.code(state: "synthetic-state", openBrowser: {}) }
        try await Task.sleep(nanoseconds: 25_000_000)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        for (path, expected) in [
            ("/unrelated", 404),
            ("/auth/callback?state=wrong&code=synthetic", 400),
            ("/auth/callback?state=synthetic-state&state=synthetic-state&code=synthetic", 400),
            ("/auth/callback?state=synthetic-state&code=synthetic", 200)
        ] {
            let (_, response) = try await session.data(from: URL(string: "http://127.0.0.1:1457\(path)")!)
            guard (response as? HTTPURLResponse)?.statusCode == expected else {
                throw ProbeFailure.message("Callback rejection check failed.")
            }
        }
        guard try await task.value == "synthetic" else { throw ProbeFailure.message("Callback code check failed.") }
        print("Loopback checks passed: bind, unrelated path, wrong state, duplicate parameters and valid single-use callback.")
    }
}
