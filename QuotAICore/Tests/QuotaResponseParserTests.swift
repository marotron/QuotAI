import XCTest
@testable import QuotAICore

final class QuotaResponseParserTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed

    func testParsesCursorModelsFromPeriodUsage() throws {
        let startMs = Int64((now.timeIntervalSince1970 - 10 * 86_400) * 1000)
        let endMs = Int64((now.timeIntervalSince1970 + 2 * 86_400) * 1000)
        let json = """
        {
          "billingCycleStart": "\(startMs)",
          "billingCycleEnd": "\(endMs)",
          "planUsage": { "autoPercentUsed": 70.0, "apiPercentUsed": 10.0 }
        }
        """.data(using: .utf8)!

        let meter = try QuotaResponseParser.cursorModels(from: json, now: now)
        XCTAssertEqual(meter.name, "Cursor Models")
        XCTAssertEqual(meter.percentUsed, 70.0)
        XCTAssertEqual(meter.secondsRemaining!, 2 * 86_400, accuracy: 1)
        XCTAssertFalse(meter.isUnavailable)
        XCTAssertNotNil(meter.pace)
        XCTAssertTrue(meter.pace!.label.contains("pace") || meter.pace!.label == "Exhausted")
    }

    func testParsesOtherModelsFromPeriodUsage() throws {
        let endMs = Int64((now.timeIntervalSince1970 + 2 * 86_400) * 1000)
        let json = """
        {
          "billingCycleStart": "1",
          "billingCycleEnd": "\(endMs)",
          "planUsage": { "autoPercentUsed": 70.0, "apiPercentUsed": 46.4 }
        }
        """.data(using: .utf8)!

        let meter = try QuotaResponseParser.otherModels(from: json, now: now)
        XCTAssertEqual(meter.name, "Other Models")
        XCTAssertEqual(meter.percentUsed, 46.4)
        XCTAssertEqual(meter.secondsRemaining!, 2 * 86_400, accuracy: 1)
        XCTAssertFalse(meter.isUnavailable)
    }

    func testOtherModelsMissingPercentIsUnavailable() throws {
        let json = #"{"billingCycleStart":"1","billingCycleEnd":"2","planUsage":{"autoPercentUsed":1}}"#.data(using: .utf8)!
        let meter = try QuotaResponseParser.otherModels(from: json, now: now)
        XCTAssertTrue(meter.isUnavailable)
    }

    func testCursorModelsMissingAutoPercentThrows() {
        let json = #"{"billingCycleStart":"1","billingCycleEnd":"2","planUsage":{}}"#.data(using: .utf8)!
        XCTAssertThrowsError(try QuotaResponseParser.cursorModels(from: json, now: now))
    }

    func testParsesEligibleGrokBot() throws {
        let start = now.addingTimeInterval(-2 * 86_400)
        let end = now.addingTimeInterval(5 * 86_400)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let json = """
        {
          "usagePercent": 46.9,
          "currentPeriodStart": "\(formatter.string(from: start))",
          "nextResetTimestampUtc": "\(formatter.string(from: end))",
          "usesPooledEnterpriseAllowance": false,
          "hasNonZeroIncludedLimit": true
        }
        """.data(using: .utf8)!

        let meter = try QuotaResponseParser.grokBot(from: json, now: now)
        XCTAssertEqual(meter.name, "Grok Bot")
        XCTAssertEqual(meter.percentUsed!, 46.9, accuracy: 0.01)
        XCTAssertEqual(meter.secondsRemaining!, 5 * 86_400, accuracy: 1)
        XCTAssertFalse(meter.isUnavailable)
        XCTAssertNotNil(meter.pace)
    }

    func testGrokBotPooledIsUnavailable() throws {
        let json = """
        {
          "usagePercent": 10,
          "usesPooledEnterpriseAllowance": true,
          "hasNonZeroIncludedLimit": true
        }
        """.data(using: .utf8)!
        let meter = try QuotaResponseParser.grokBot(from: json, now: now)
        XCTAssertTrue(meter.isUnavailable)
        XCTAssertNil(meter.percentUsed)
    }

    func testGrokBotMissingUsagePercentIsUnavailable() throws {
        let json = #"{"hasNonZeroIncludedLimit":true}"#.data(using: .utf8)!
        let meter = try QuotaResponseParser.grokBot(from: json, now: now)
        XCTAssertTrue(meter.isUnavailable)
    }
}
