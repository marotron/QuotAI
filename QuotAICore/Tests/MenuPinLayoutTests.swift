import XCTest
@testable import QuotAICore

final class MenuPinLayoutTests: XCTestCase {
    func testAllPinsOff_noSections() {
        XCTAssertEqual(MenuPinLayout.sections(isOn: { _ in false }), [])
    }

    func testAllPinsOn_sectionsInGroupOrder() {
        let sections = MenuPinLayout.sections(isOn: { _ in true })
        XCTAssertEqual(sections.map(\.group), [.actions, .display, .besideMeter, .blink])
    }

    func testEmptyGroupsAreDropped() {
        let sections = MenuPinLayout.sections(isOn: { $0 == .blink })
        XCTAssertEqual(sections, [MenuPinSection(group: .blink, pins: [.blink])])
    }

    func testPinsKeepEnumOrderWithinGroup() {
        let sections = MenuPinLayout.sections(isOn: { [.openCursorSpending, .refreshCursor].contains($0) })
        XCTAssertEqual(
            sections,
            [MenuPinSection(group: .actions, pins: [.refreshCursor, .openCursorSpending])]
        )
    }

    func testEveryPinBelongsToExactlyOneSection() {
        let sections = MenuPinLayout.sections(isOn: { _ in true })
        let flattened = sections.flatMap(\.pins)
        XCTAssertEqual(Set(flattened), Set(MenuPin.allCases))
        XCTAssertEqual(flattened.count, MenuPin.allCases.count)
    }

    func testDensityColumnCounts() {
        XCTAssertEqual(MenuPinDensity.compact.columnCount, 2)
        XCTAssertEqual(MenuPinDensity.normal.columnCount, 1)
    }

    func testRawValuesAreUniqueAppStorageKeys() {
        let keys = MenuPin.allCases.map(\.rawValue)
        XCTAssertEqual(Set(keys).count, keys.count)
        XCTAssertTrue(keys.allSatisfy { $0.hasPrefix("pin") })
    }
}
