import Foundation
import QuotAICore

enum CursorUsageBillingClient {
    struct Result: Sendable {
        var records: [CursorUsageBillingRecord]
        var complete: Bool
        var requests: Int
        var bytes: Int
    }

    /// At most two pages per window; caller schedules at most two windows per ten minutes.
    static func fetch(
        window: CursorUsageBillingWindow, accessToken: String, session: URLSession = .shared
    ) async throws -> Result {
        let pageSize = 100
        var records: [CursorUsageBillingRecord] = []
        var bytes = 0
        var requests = 0
        for page in 1...2 {
            try Task.checkCancellation()
            var request = URLRequest(url: URL(string: "https://api2.cursor.sh/aiserver.v1.DashboardService/GetFilteredUsageEvents")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
            request.timeoutInterval = 10
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "startDate": String(Int64(floor(window.start.timeIntervalSince1970 * 1000))),
                "endDate": String(Int64(ceil(window.end.timeIntervalSince1970 * 1000))),
                "page": page, "pageSize": pageSize,
            ])
            let (data, response) = try await session.data(for: request)
            requests += 1
            guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                  data.count <= 1_048_576 else { throw CocoaError(.fileReadUnknown) }
            bytes += data.count
            let parsed = try CursorUsageBillingPage.parse(data)
            guard parsed.records.count <= pageSize else { throw CocoaError(.coderReadCorrupt) }
            records.append(contentsOf: parsed.records)
            guard Set(records.map(\.id)).count == records.count,
                  records.count <= parsed.totalCount else { throw CocoaError(.coderReadCorrupt) }
            if records.count >= parsed.totalCount {
                return Result(records: records, complete: true, requests: page, bytes: bytes)
            }
            if parsed.records.isEmpty { break }
        }
        return Result(records: records, complete: false, requests: requests, bytes: bytes)
    }
}
