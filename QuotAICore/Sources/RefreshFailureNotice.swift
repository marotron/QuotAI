import Foundation

/// Copy and provider list for the single below-chart refresh-failure notice.
public enum RefreshFailureNotice {
    public enum Provider: String, CaseIterable, Equatable, Sendable {
        case cursor
        case grok
        case codex

        public var displayName: String {
            switch self {
            case .cursor: return "Cursor"
            case .grok: return "Grok"
            case .codex: return "Codex"
            }
        }
    }

    /// Providers that failed this attempt. Cursor and Grok share `QuotaStore.refreshError`.
    public static func providers(cursorGrokFailed: Bool, codexFailed: Bool) -> [Provider] {
        var list: [Provider] = []
        if cursorGrokFailed {
            list.append(.cursor)
            list.append(.grok)
        }
        if codexFailed {
            list.append(.codex)
        }
        return list
    }

    public static func joinNames(_ providers: [Provider]) -> String {
        let names = providers.map(\.displayName)
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names[names.count - 1])"
        }
    }

    /// Title prefers the Cursor/Grok failure string when present.
    public static func title(cursorGrokMessage: String?) -> String {
        if let cursorGrokMessage, !cursorGrokMessage.isEmpty {
            return cursorGrokMessage
        }
        return "Refresh failed"
    }

    public static func body(providers: [Provider]) -> String {
        let who = joinNames(providers)
        guard !who.isEmpty else {
            return "Previous readings were kept. Check your connection, then try Refresh all."
        }
        return "\(who) could not refresh. Previous readings were kept. Check your connection, then try Refresh all."
    }
}
