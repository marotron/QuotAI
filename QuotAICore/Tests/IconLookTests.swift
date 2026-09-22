import XCTest
@testable import QuotAICore

final class IconLookTests: XCTestCase {
    func testCasesMatchSettingsPickerOrder() {
        XCTAssertEqual(
            IconLook.allCases.map(\.rawValue),
            ["bars", "ringsPerQuota", "ringsPaired", "ringsPace"]
        )
    }

    func testRawValueRoundTrip() {
        for look in IconLook.allCases {
            XCTAssertEqual(IconLook(rawValue: look.rawValue), look)
        }
    }

    func testRingCenterContentCasesMatchSettingsPickerOrder() {
        XCTAssertEqual(
            RingCenterContent.allCases.map(\.rawValue),
            ["none", "remaining", "icon"]
        )
    }

    func testRingCenterContentRawValueRoundTrip() {
        for content in RingCenterContent.allCases {
            XCTAssertEqual(RingCenterContent(rawValue: content.rawValue), content)
        }
    }
}
