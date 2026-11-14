import XCTest
@testable import QuotAICore

private final class BillingURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

final class CursorUsageBillingClientTests: XCTestCase {
    private func session() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BillingURLProtocol.self]
        return URLSession(configuration: config)
    }

    func testPaginationIsBoundedAndIncompleteCannotProveFree() async throws {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let window = CursorUsageBillingWindow(start: start, end: start.addingTimeInterval(60), turnIDs: [])
        var calls = 0
        BillingURLProtocol.handler = { request in
            calls += 1
            XCTAssertEqual(request.url?.path, "/aiserver.v1.DashboardService/GetFilteredUsageEvents")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only")
            XCTAssertEqual(request.timeoutInterval, 10)
            let rows = (0..<100).map { index in
                ["usageEventId": "page\(calls)-\(index)", "timestamp": "1800000000500", "model": "default", "isChargeable": false] as [String: Any]
            }
            return (200, try JSONSerialization.data(withJSONObject: ["totalUsageEventsCount": 300, "usageEventsDisplay": rows]))
        }
        let session = session()
        defer { session.invalidateAndCancel(); BillingURLProtocol.handler = nil }
        let result = try await CursorUsageBillingClient.fetch(window: window, accessToken: "test-only", session: session)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(result.requests, 2)
        XCTAssertEqual(result.records.count, 200)
        XCTAssertFalse(result.complete)
    }

    func testUnauthorizedDoesNotRetryOrCreateEvidence() async {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let window = CursorUsageBillingWindow(start: start, end: start.addingTimeInterval(60), turnIDs: [])
        var calls = 0
        BillingURLProtocol.handler = { _ in calls += 1; return (401, Data("{}".utf8)) }
        let session = session()
        defer { session.invalidateAndCancel(); BillingURLProtocol.handler = nil }
        do {
            _ = try await CursorUsageBillingClient.fetch(window: window, accessToken: "test-only", session: session)
            XCTFail("Expected a failed lookup")
        } catch { XCTAssertEqual(calls, 1) }
    }
}
