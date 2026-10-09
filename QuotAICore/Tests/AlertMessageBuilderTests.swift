import XCTest
@testable import QuotAICore

final class AlertMessageBuilderTests: XCTestCase {
    func testSubjectListsAlertingMetersCompactly() {
        let alerts = [
            PaceAlertMeterAlert(id: "cursor", name: "Cursor Models", kind: .over),
            PaceAlertMeterAlert(id: "grok", name: "Grok Bot", kind: .under)
        ]
        let subject = AlertMessageBuilder.subject(alerts: alerts)
        XCTAssertEqual(subject, "Cursor over · Grok under")
    }

    func testSubjectCollapsesSharedKind() {
        let alerts = [
            PaceAlertMeterAlert(id: "cursor", name: "Cursor Models", kind: .over),
            PaceAlertMeterAlert(id: "grok", name: "Grok Bot", kind: .over)
        ]
        XCTAssertEqual(
            AlertMessageBuilder.subject(alerts: alerts),
            "Cursor · Grok over"
        )
    }

    func testBodyIsOneCompactLinePerMeter() {
        let body = AlertMessageBuilder.body(alerts: [
            PaceAlertMeterDetail(
                id: "cursor",
                name: "Cursor Models",
                kind: .over,
                percentUsed: 74.2,
                elapsedPercent: 65.6
            ),
            PaceAlertMeterDetail(
                id: "grok",
                name: "Grok Bot",
                kind: .over,
                percentUsed: 38.3,
                elapsedPercent: 15.5
            )
        ])
        XCTAssertEqual(
            body,
            """
            ▲ Cursor 74% / 66%
            ▲ Grok 38% / 16%
            """
        )
    }

    func testExhaustedWording() {
        let subject = AlertMessageBuilder.subject(alerts: [
            PaceAlertMeterAlert(id: "cursor", name: "Cursor Models", kind: .exhausted)
        ])
        XCTAssertEqual(subject, "Cursor exhausted")
    }

    func testShortLabels() {
        XCTAssertEqual(AlertMessageBuilder.shortLabel(id: "cursor", name: "Cursor Models"), "Cursor")
        XCTAssertEqual(AlertMessageBuilder.shortLabel(id: "other", name: "Other Models"), "Other")
        XCTAssertEqual(AlertMessageBuilder.shortLabel(id: "grok", name: "Grok Bot"), "Grok")
    }
}
