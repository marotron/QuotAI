import XCTest
@testable import QuotAICore

final class MenuPresenterTests: XCTestCase {
    func testBarTitleUsedAndDays() {
        let cursor = QuotaMeter(name: "Cursor Models", percentUsed: 70, secondsRemaining: 1 * 86_400)
        let grok = QuotaMeter(name: "Grok Bot", percentUsed: 47, secondsRemaining: 5 * 86_400)
        let view = MenuPresenter.present(cursorModels: cursor, grokBot: grok)
        XCTAssertEqual(view.barTitle, "Cur 70%/1d · Grok 47%/5d")
        XCTAssertEqual(view.spendingURL.absoluteString, "https://cursor.com/dashboard/spending")
        XCTAssertEqual(view.meters.count, 2)
    }

    func testBarUsesHoursWhenUnderOneDay() {
        let cursor = QuotaMeter(name: "Cursor Models", percentUsed: 71, secondsRemaining: 5 * 3_600)
        let grok = QuotaMeter(name: "Grok Bot", percentUsed: 47, secondsRemaining: 5 * 86_400)
        let view = MenuPresenter.present(cursorModels: cursor, grokBot: grok)
        XCTAssertEqual(view.barTitle, "Cur 71%/5h · Grok 47%/5d")
        XCTAssertTrue(view.meters[0].title.contains("5h"))
    }

    func testMenuRowShowsPrecisePercentAndDetailedTime() {
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 0.31777777777777777,
            secondsRemaining: 29 * 86_400 + 14 * 3_600
        )
        let grok = QuotaMeter(name: "Grok Bot", percentUsed: 46.4, secondsRemaining: 5 * 86_400)
        let view = MenuPresenter.present(cursorModels: cursor, grokBot: grok)
        XCTAssertTrue(view.meters[0].title.contains("0.32% used"), view.meters[0].title)
        XCTAssertTrue(view.meters[0].title.contains("29d 14h"), view.meters[0].title)
        XCTAssertTrue(view.meters[1].title.contains("46.4% used"), view.meters[1].title)
        // Bar glance is a whole %: 0.32 rounds down, 46.4 rounds to 46.
        XCTAssertTrue(view.barTitle.contains("0%"), view.barTitle)
        XCTAssertTrue(view.barTitle.contains("46%"), view.barTitle)
    }

    func testMenuRowShowsUsedOverElapsedArrowPace() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(100 * 86_400)
        let now = start.addingTimeInterval(2 * 86_400) // 2% through period
        let pace = PaceCalculator.pace(percentUsed: 1.64, periodStart: start, periodEnd: end, now: now)
        XCTAssertEqual(Int((pace.ratio! * 100).rounded()), 82)
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 1.64,
            secondsRemaining: 98 * 86_400,
            pace: pace,
            periodStart: start,
            periodEnd: end
        )
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
                        now: now
        )
        XCTAssertEqual(
            view.meters[0].title,
            "Cursor Models: 1.64% used / 2% elapsed → 82% pace · 98d"
        )
        XCTAssertEqual(view.meters[0].band, .under)
        XCTAssertEqual(view.meters[0].symbolName, "snowflake")
        XCTAssertEqual(view.meters[0].note, "At this pace ~18% of quota unused by reset")
    }

    func testMenuRowShowsElapsedPercentBesideUsed() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(10 * 86_400)
        let now = start.addingTimeInterval(4 * 86_400) // 40% through period
        let pace = PaceCalculator.pace(percentUsed: 25, periodStart: start, periodEnd: end, now: now)
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 25,
            secondsRemaining: 6 * 86_400,
            pace: pace,
            periodStart: start,
            periodEnd: end
        )
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
                        now: now
        )
        let pacePct = Int((pace.ratio! * 100).rounded())
        XCTAssertEqual(
            view.meters[0].title,
            "Cursor Models: 25% used / 40% elapsed → \(pacePct)% pace · 6d"
        )
        XCTAssertEqual(view.meters[0].band, .under)
        XCTAssertNotNil(view.meters[0].note)
        XCTAssertTrue(view.meters[0].note!.contains("unused by reset"), view.meters[0].note!)
    }

    func testMenuRowShowsPreciseElapsed() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(100 * 86_400)
        let now = start.addingTimeInterval(15.234 * 86_400)
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 15.75,
            secondsRemaining: 84 * 86_400,
            periodStart: start,
            periodEnd: end
        )
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
            now: now
        )
        let elapsed = QuotaPercent.precise(cursor.periodElapsedPercent(now: now)!)
        XCTAssertTrue(elapsed.contains("."), elapsed)
        XCTAssertTrue(view.meters[0].title.contains("15.75% used / \(elapsed) elapsed"), view.meters[0].title)
    }

    func testUnderNoteShowsProjectedWaste() {
        let pace = PaceResult(ratio: 0.88, label: "", isEarly: false, daysToExhaustion: 40)
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 1.76,
            secondsRemaining: 29 * 86_400,
            pace: pace,
            periodStart: Date(),
            periodEnd: Date().addingTimeInterval(30 * 86_400)
        )
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
        )
        XCTAssertEqual(view.meters[0].band, .under)
        XCTAssertEqual(view.meters[0].symbolName, "snowflake")
        XCTAssertEqual(view.meters[0].shade, .mild)
        XCTAssertEqual(view.meters[0].note, "At this pace ~12% of quota unused by reset")
    }

    func testOnPaceUsesCheckmarkIcon() {
        let pace = PaceResult(ratio: 1.0, label: "", isEarly: false, daysToExhaustion: 30)
        let cursor = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 50,
            secondsRemaining: 15 * 86_400,
            pace: pace
        )
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
        )
        XCTAssertEqual(view.meters[0].band, .on)
        XCTAssertEqual(view.meters[0].symbolName, "checkmark")
        XCTAssertNil(view.meters[0].note)
    }

    func testOverNoteShowsEmptyAndIdleDays() {
        let pace = PaceResult(ratio: 1.40, label: "", isEarly: true, daysToExhaustion: 4)
        let cursor = QuotaMeter(
            name: "Grok Bot",
            percentUsed: 60,
            secondsRemaining: 29 * 86_400,
            pace: pace
        )
        let view = MenuPresenter.present(
            cursorModels: QuotaMeter(name: "Cursor Models", isUnavailable: true),
            grokBot: cursor,
        )
        XCTAssertEqual(view.meters[1].band, .over)
        XCTAssertEqual(view.meters[1].symbolName, "flame.fill")
        XCTAssertEqual(view.meters[1].shade, .medium)
        XCTAssertEqual(view.meters[1].note, "Empties in ~4d · then ~25d with no quota")
    }

    func testUnavailableGrok() {
        let cursor = QuotaMeter(name: "Cursor Models", percentUsed: 10, secondsRemaining: 20 * 86_400)
        let grok = QuotaMeter(name: "Grok Bot", isUnavailable: true)
        let view = MenuPresenter.present(cursorModels: cursor, grokBot: grok)
        XCTAssertTrue(view.meters[1].title.contains("unavailable"))
        XCTAssertEqual(view.barTitle, "Cur 10%/20d")
    }

    func testSymbolTracksWorstMeter() {
        func symbol(_ cur: Double?, _ grok: Double?) -> String {
            MenuPresenter.present(
                cursorModels: QuotaMeter(name: "Cursor Models", percentUsed: cur),
                grokBot: QuotaMeter(name: "Grok Bot", percentUsed: grok)
            ).symbolName
        }
        XCTAssertEqual(symbol(5, 10), "gauge.with.dots.needle.0percent")
        XCTAssertEqual(symbol(30, 10), "gauge.with.dots.needle.33percent")
        XCTAssertEqual(symbol(45, 55), "gauge.with.dots.needle.50percent")
        XCTAssertEqual(symbol(70, 10), "gauge.with.dots.needle.67percent")
        XCTAssertEqual(symbol(95, 10), "gauge.with.dots.needle.100percent")
        XCTAssertEqual(symbol(nil, nil), "gauge.with.dots.needle.0percent")
    }


    func testTintFollowsLevel() {
        func tint(_ cur: Double?, authError: String? = nil) -> SymbolTint {
            MenuPresenter.present(
                cursorModels: QuotaMeter(name: "Cursor Models", percentUsed: cur),
                grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
                                authError: authError
            ).tint
        }
        XCTAssertEqual(tint(nil), .neutral)
        XCTAssertEqual(tint(20), .ok)
        XCTAssertEqual(tint(50), .warning)
        XCTAssertEqual(tint(80), .critical)
        XCTAssertEqual(tint(20, authError: "Auth error"), .critical)
    }

    func testPaceTintFollowsGreenBand() {
        func paceTint(ratio: Double?, exhausted: Bool = false) -> SymbolTint {
            let pace: PaceResult?
            if exhausted {
                pace = PaceResult(ratio: nil, label: "Exhausted", isEarly: false, daysToExhaustion: 0)
            } else if let ratio {
                pace = PaceResult(ratio: ratio, label: "", isEarly: false, daysToExhaustion: nil)
            } else {
                pace = nil
            }
            return MenuPresenter.tint(pace: pace)
        }
        XCTAssertEqual(paceTint(ratio: nil), .neutral)
        XCTAssertEqual(paceTint(ratio: 0.5), .under)
        XCTAssertEqual(paceTint(ratio: 1.0), .ok)
        XCTAssertEqual(paceTint(ratio: 0.95), .ok)
        XCTAssertEqual(paceTint(ratio: 1.03), .ok) // inside ±10% dead zone
        XCTAssertEqual(paceTint(ratio: 1.2), .warning)
        XCTAssertEqual(paceTint(ratio: nil, exhausted: true), .critical)
    }

    func testEarlyInsideDeadZoneIsOnNotOver() {
        // Slightly over 100% → isEarly, but still inside 90–110% → on (not fire).
        let pace = PaceResult(ratio: 1.03, label: "", isEarly: true, daysToExhaustion: 29)
        let view = MenuPresenter.present(
            cursorModels: QuotaMeter(
                name: "Cursor Models",
                percentUsed: 2.06,
                secondsRemaining: 29 * 86_400,
                pace: pace
            ),
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
        )
        XCTAssertEqual(view.meters[0].band, .on)
        XCTAssertEqual(view.meters[0].symbolName, "checkmark")
        XCTAssertNil(view.meters[0].note)
        XCTAssertEqual(MenuPresenter.tint(pace: pace), .ok)
    }

    func testCustomDeadZoneSharedByBandAndTint() {
        let pace = PaceResult(ratio: 1.08, label: "", isEarly: true, daysToExhaustion: 25)
        // Tight ±5% → 108% is over.
        let tight = MenuPresenter.present(
            cursorModels: QuotaMeter(name: "Cursor Models", percentUsed: 50, pace: pace),
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
            onPaceLo: 0.95,
            onPaceHi: 1.05
        )
        XCTAssertEqual(tight.meters[0].band, .over)
        XCTAssertEqual(MenuPresenter.tint(pace: pace, onPaceLo: 0.95, onPaceHi: 1.05), .warning)

        // Wide ±20% → 108% is on.
        let wide = MenuPresenter.present(
            cursorModels: QuotaMeter(name: "Cursor Models", percentUsed: 50, pace: pace),
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
            onPaceLo: 0.80,
            onPaceHi: 1.20
        )
        XCTAssertEqual(wide.meters[0].band, .on)
        XCTAssertEqual(MenuPresenter.tint(pace: pace, onPaceLo: 0.80, onPaceHi: 1.20), .ok)
    }

    func testAuthErrorSymbol() {
        let view = MenuPresenter.present(
            cursorModels: QuotaMeter(name: "Cursor Models"),
            grokBot: QuotaMeter(name: "Grok Bot"),
            authError: "Auth error"
        )
        XCTAssertEqual(view.symbolName, "exclamationmark.triangle")
    }

    func testAuthErrorRow() {
        let cursor = QuotaMeter(name: "Cursor Models")
        let grok = QuotaMeter(name: "Grok Bot", isUnavailable: true)
        let view = MenuPresenter.present(
            cursorModels: cursor,
            grokBot: grok,
            authError: "Auth error — re-auth or paste token"
        )
        XCTAssertEqual(view.notices.first, "Auth error — re-auth or paste token")
        XCTAssertEqual(view.barTitle, "QuotAI · auth")
    }

    func testProjectedClockMovesRemainingAndPace() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(10 * 86_400)
        let fetched = start.addingTimeInterval(4 * 86_400)
        let later = fetched.addingTimeInterval(90 * 60)
        let fetchedPace = PaceCalculator.pace(percentUsed: 50, periodStart: start, periodEnd: end, now: fetched)
        let meter = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 50,
            secondsRemaining: end.timeIntervalSince(fetched),
            pace: fetchedPace,
            periodStart: start,
            periodEnd: end
        )
        let live = meter.projected(at: later)
        XCTAssertEqual(live.secondsRemaining!, end.timeIntervalSince(later), accuracy: 0.001)
        XCTAssertNotEqual(live.pace?.ratio, fetchedPace.ratio)
        XCTAssertEqual(
            live.secondsRemaining(at: later)!,
            end.timeIntervalSince(later),
            accuracy: 0.001
        )

        let view = MenuPresenter.present(
            cursorModels: live,
            grokBot: QuotaMeter(name: "Grok Bot", isUnavailable: true),
            now: later
        )
        let remaining = RemainingTime.formatDetailed(seconds: end.timeIntervalSince(later))
        XCTAssertTrue(view.meters[0].title.contains(remaining), view.meters[0].title)
        let pacePct = Int((live.pace!.ratio! * 100).rounded())
        XCTAssertTrue(view.meters[0].title.contains("\(pacePct)% pace"), view.meters[0].title)
        XCTAssertNotNil(view.meters[0].note)
    }

    func testProjectedKeepsSnapshotWithoutBillingWindow() {
        let pace = PaceResult(ratio: 0.5, label: "Under", isEarly: false, daysToExhaustion: 3)
        let meter = QuotaMeter(
            name: "Cursor Models",
            percentUsed: 10,
            secondsRemaining: 100,
            pace: pace
        )
        let later = meter.projected(at: Date().addingTimeInterval(3_600))
        XCTAssertEqual(later.secondsRemaining, 100)
        XCTAssertEqual(later.pace, pace)
        XCTAssertEqual(later.secondsRemaining(at: Date()), 100)
    }

    func testRefreshFailureKeepsGlanceTitle() {
        let view = MenuPresenter.present(
            cursorModels: QuotaMeter(name: "Cursor Models", percentUsed: 13),
            grokBot: QuotaMeter(name: "Grok Bot", percentUsed: 57),
            notice: "Refresh failed"
        )
        XCTAssertEqual(view.notices.first, "Refresh failed")
        XCTAssertNotEqual(view.barTitle, "QuotAI · auth")
        XCTAssertNotEqual(view.symbolName, "exclamationmark.triangle")
    }
}
