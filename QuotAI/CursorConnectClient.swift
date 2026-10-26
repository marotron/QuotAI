import Foundation
import QuotAICore

enum CursorConnectClient {
    static let oauthClientID = "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB"

    enum ClientError: Error, Equatable {
        case httpStatus(Int)
        case unauthorized
        case shouldLogout
        case refreshFailed
        case badPayload
    }

    enum FetchScope: Equatable, Sendable {
        case all
        case cursor
        case grok
    }

    /// Meters present for the requested scope; others are nil (caller keeps existing).
    struct FetchResult {
        var cursorModels: QuotaMeter?
        var otherModels: QuotaMeter?
        var grokBot: QuotaMeter?
        var credentials: QuotAIKeychain.Credentials
    }

    static func fetchMeters(
        credentials: QuotAIKeychain.Credentials,
        scope: FetchScope = .all,
        session: URLSession = .shared,
        now: Date = Date()
    ) async throws -> FetchResult {
        var creds = credentials
        do {
            return try await fetchOnce(credentials: creds, scope: scope, session: session, now: now)
        } catch ClientError.unauthorized {
            creds = try await refresh(credentials: creds, session: session)
            return try await fetchOnce(credentials: creds, scope: scope, session: session, now: now)
        }
    }

    private static func fetchOnce(
        credentials: QuotAIKeychain.Credentials,
        scope: FetchScope,
        session: URLSession,
        now: Date
    ) async throws -> FetchResult {
        let wantCursor = scope == .all || scope == .cursor
        let wantGrok = scope == .all || scope == .grok

        var periodData: Data?
        var sandData: Data?

        if wantCursor && wantGrok {
            async let period = connectPost(
                url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!,
                accessToken: credentials.accessToken,
                session: session
            )
            async let sand = connectPost(
                url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus")!,
                accessToken: credentials.accessToken,
                session: session
            )
            periodData = try await period
            sandData = try await sand
        } else if wantCursor {
            periodData = try await connectPost(
                url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage")!,
                accessToken: credentials.accessToken,
                session: session
            )
        } else if wantGrok {
            sandData = try await connectPost(
                url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus")!,
                accessToken: credentials.accessToken,
                session: session
            )
        }

        var cursor: QuotaMeter?
        var other: QuotaMeter?
        var grok: QuotaMeter?
        if let periodData {
            cursor = try QuotaResponseParser.cursorModels(from: periodData, now: now)
            other = try QuotaResponseParser.otherModels(from: periodData, now: now)
        }
        if let sandData {
            grok = try QuotaResponseParser.grokBot(from: sandData, now: now)
        }
        return FetchResult(
            cursorModels: cursor,
            otherModels: other,
            grokBot: grok,
            credentials: credentials
        )
    }

    private static func connectPost(url: URL, accessToken: String, session: URLSession) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badPayload }
        if http.statusCode == 401 { throw ClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else { throw ClientError.httpStatus(http.statusCode) }
        return data
    }

    private static func refresh(
        credentials: QuotAIKeychain.Credentials,
        session: URLSession
    ) async throws -> QuotAIKeychain.Credentials {
        var request = URLRequest(url: URL(string: "https://api2.cursor.sh/oauth/token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "grant_type": "refresh_token",
            "client_id": oauthClientID,
            "refresh_token": credentials.refreshToken,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.refreshFailed }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClientError.refreshFailed
        }
        if obj["shouldLogout"] as? Bool == true { throw ClientError.shouldLogout }
        guard http.statusCode == 200, let access = obj["access_token"] as? String, !access.isEmpty else {
            throw ClientError.refreshFailed
        }
        let newRefresh = (obj["refresh_token"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? credentials.refreshToken
        return QuotAIKeychain.Credentials(
            accessToken: access,
            refreshToken: newRefresh,
            cachedEmail: credentials.cachedEmail
        )
    }
}
