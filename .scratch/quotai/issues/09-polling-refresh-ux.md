# Polling and refresh UX

Type: grilling
Status: open
Blocked by:

## Question

How often should QuotAI refresh live Cursor Spending meters in the menu bar, and what manual refresh affordances exist in v1?

Cover at least:

- Automatic poll interval (if any) while the app is running
- Whether opening the dropdown triggers a refresh
- Explicit **Refresh** menu action (yes/no)
- How this interacts with the locked rule of **one pace sample per meter per local calendar day** (live `%` / days can update more often; pace sample still once/day)

Why it matters: live fetch wiring needs a locked refresh policy before the menu is hooked to the network; otherwise the app either hammers unofficial endpoints or looks stale.

## Comments

### 2026-09-19 (~19:45)

Unclaimed — build handoff took priority (live fetch not blocked on polling). Resume grilling when ready.

### 2026-09-19 (~21:00)

Build session shipped a default rather than grilling: poll every **10 min** while running, refresh on **wake from sleep**, explicit **Refresh** menu action. Opening the dropdown does not refresh. Pace sample stays once/day (`PaceSampleStore`).

Interval is now a user setting ("Refresh every": 5 / 10 / 15 / 30 min / 1 h, default 10). 1 h is the ceiling by design.

### 2026-09-19 (~21:15)

Polling was unreliable: `Task.sleep` + App Nap on `LSUIElement`, and re-assigning the interval Picker restarted the sleep from zero. Switched to a main RunLoop `Timer` + `ProcessInfo` activity, ignore same-value `didSet`, and refresh when the menu opens if data is older than the interval.
