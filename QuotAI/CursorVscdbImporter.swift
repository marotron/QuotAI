import Foundation
import QuotAICore
import SQLite3

enum CursorVscdbImporter {
    static var defaultDatabaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    static func importCredentials(from databaseURL: URL = defaultDatabaseURL) throws -> QuotAIKeychain.Credentials? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return nil }

        var db: OpaquePointer?
        let path = "file:\(databaseURL.path)?mode=ro"
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK, let db else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        defer { sqlite3_close(db) }

        func value(for key: String) -> String? {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            guard sqlite3_prepare_v2(db, "SELECT value FROM ItemTable WHERE key = ?", -1, &stmt, nil) == SQLITE_OK else {
                return nil
            }
            _ = key.withCString { cString in
                sqlite3_bind_text(stmt, 1, cString, -1, nil)
            }
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            guard let cStr = sqlite3_column_text(stmt, 0) else { return nil }
            let s = String(cString: cStr).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        }

        let access = value(for: "cursorAuth/accessToken")
        let refresh = value(for: "cursorAuth/refreshToken")
        let email = value(for: "cursorAuth/cachedEmail")
        guard let access, let refresh else { return nil }
        return QuotAIKeychain.Credentials(accessToken: access, refreshToken: refresh, cachedEmail: email)
    }
}
