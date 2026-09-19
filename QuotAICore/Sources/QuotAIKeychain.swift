import Foundation

/// Keychain item shape locked in Auth grilling — adapter stub for scaffold.
public enum QuotAIKeychain {
    public static let service = "dev.marotron.QuotAI"
    public static let account = "default"

    public struct Credentials: Codable, Equatable, Sendable {
        public var accessToken: String
        public var refreshToken: String
        public var cachedEmail: String?

        public init(accessToken: String, refreshToken: String, cachedEmail: String? = nil) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.cachedEmail = cachedEmail
        }
    }
}
