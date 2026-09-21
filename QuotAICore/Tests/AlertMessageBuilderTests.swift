import XCTest
@testable import QuotAICore

final class AlertMessageBuilderTests: XCTestCase {
    func testSubjectListsAlertingMeters() {
        let alerts = [
            PaceAlertMeterAlert(id: "cursor", name: "Cursor Models", kind: .over),
            PaceAlertMeterAlert(id: "grok", name: "Grok Bot", kind: .under)
        ]
        let subject = AlertMessageBuilder.subject(alerts: alerts)
        XCTAssertEqual(subject, "QuotAI: Cursor Models over · Grok Bot under")
    }

    func testBodyIncludesUsedAndElapsed() {
        let body = AlertMessageBuilder.body(alerts: [
            PaceAlertMeterDetail(
                name: "Cursor Models",
                kind: .over,
                percentUsed: 50,
                elapsedPercent: 10
            )
        ])
        XCTAssertTrue(body.contains("Cursor Models"))
        XCTAssertTrue(body.contains("over"))
        XCTAssertTrue(body.contains("50% used"))
        XCTAssertTrue(body.contains("10% elapsed"))
    }

    func testExhaustedWording() {
        let subject = AlertMessageBuilder.subject(alerts: [
            PaceAlertMeterAlert(id: "cursor", name: "Cursor Models", kind: .exhausted)
        ])
        XCTAssertEqual(subject, "QuotAI: Cursor Models exhausted")
    }
}
