import Foundation

/// Quota families that share one Connect call each.
public enum RefreshFamily: Equatable, Sendable, CaseIterable {
    case cursor
    case grok
}

/// When to poll Cursor vs Grok under one shared schedule or fixed interval.
public enum RefreshPlanner {
    /// Families whose last fetch is missing or at least as old as their interval.
    public static func dueFamilies(
        dynamic: Bool,
        fixedMinutes: Int,
        schedule: RefreshSchedule,
        cursorPeriodEnds: [Date],
        grokPeriodEnds: [Date],
        lastCursor: Date?,
        lastGrok: Date?,
        now: Date
    ) -> [RefreshFamily] {
        let cursorInterval = interval(
            dynamic: dynamic,
            fixedMinutes: fixedMinutes,
            schedule: schedule,
            periodEnds: cursorPeriodEnds,
            now: now
        )
        let grokInterval = interval(
            dynamic: dynamic,
            fixedMinutes: fixedMinutes,
            schedule: schedule,
            periodEnds: grokPeriodEnds,
            now: now
        )
        var due: [RefreshFamily] = []
        if isDue(last: lastCursor, interval: cursorInterval, now: now) {
            due.append(.cursor)
        }
        if isDue(last: lastGrok, interval: grokInterval, now: now) {
            due.append(.grok)
        }
        return due
    }

    /// Earliest wall time a family becomes due (or `now` if already due / never fetched).
    public static func nextFire(
        dynamic: Bool,
        fixedMinutes: Int,
        schedule: RefreshSchedule,
        cursorPeriodEnds: [Date],
        grokPeriodEnds: [Date],
        lastCursor: Date?,
        lastGrok: Date?,
        now: Date
    ) -> Date {
        let cursorInterval = interval(
            dynamic: dynamic,
            fixedMinutes: fixedMinutes,
            schedule: schedule,
            periodEnds: cursorPeriodEnds,
            now: now
        )
        let grokInterval = interval(
            dynamic: dynamic,
            fixedMinutes: fixedMinutes,
            schedule: schedule,
            periodEnds: grokPeriodEnds,
            now: now
        )
        let cursorFire = dueAt(last: lastCursor, interval: cursorInterval, now: now)
        let grokFire = dueAt(last: lastGrok, interval: grokInterval, now: now)
        return min(cursorFire, grokFire)
    }

    private static func interval(
        dynamic: Bool,
        fixedMinutes: Int,
        schedule: RefreshSchedule,
        periodEnds: [Date],
        now: Date
    ) -> TimeInterval {
        if dynamic {
            return schedule.interval(periodEnds: periodEnds, now: now)
        }
        return TimeInterval(max(1, fixedMinutes) * 60)
    }

    private static func isDue(last: Date?, interval: TimeInterval, now: Date) -> Bool {
        guard let last else { return true }
        return now.timeIntervalSince(last) >= interval
    }

    private static func dueAt(last: Date?, interval: TimeInterval, now: Date) -> Date {
        guard let last else { return now }
        let at = last.addingTimeInterval(interval)
        return at > now ? at : now
    }
}
