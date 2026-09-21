import XCTest
@testable import QuotAICore

final class PaceAlertCooldownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let cooldown: TimeInterval = 3600

    func testNewEdgeDelivers() {
        let ok = PaceAlertCooldown.shouldDeliver(
            signature: "cursor:over",
            now: now,
            lastSignature: nil,
            lastDeliveredAt: nil,
            cooldown: cooldown
        )
        XCTAssertTrue(ok)
    }

    func testSameSignatureWithinCooldownSuppresses() {
        let ok = PaceAlertCooldown.shouldDeliver(
            signature: "cursor:over",
            now: now,
            lastSignature: "cursor:over",
            lastDeliveredAt: now.addingTimeInterval(-60),
            cooldown: cooldown
        )
        XCTAssertFalse(ok)
    }

    func testSameSignatureAfterCooldownDelivers() {
        let ok = PaceAlertCooldown.shouldDeliver(
            signature: "cursor:over",
            now: now,
            lastSignature: "cursor:over",
            lastDeliveredAt: now.addingTimeInterval(-cooldown),
            cooldown: cooldown
        )
        XCTAssertTrue(ok)
    }

    func testSignatureChangeDeliversEvenInsideCooldown() {
        let ok = PaceAlertCooldown.shouldDeliver(
            signature: "cursor:over|grok:under",
            now: now,
            lastSignature: "cursor:over",
            lastDeliveredAt: now.addingTimeInterval(-10),
            cooldown: cooldown
        )
        XCTAssertTrue(ok)
    }

    func testEmptySignatureNeverDelivers() {
        let ok = PaceAlertCooldown.shouldDeliver(
            signature: "",
            now: now,
            lastSignature: "cursor:over",
            lastDeliveredAt: nil,
            cooldown: cooldown
        )
        XCTAssertFalse(ok)
    }
}
