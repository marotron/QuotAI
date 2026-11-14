# Automatic refresh: quiet hours and usage thresholds

Decision date: 2026-11-14. Status: **0.20.0 release; acceptance verification remains incomplete**. Release authorized on 2026-11-14 with the outstanding checks below. This contract covers [#31](https://github.com/marotron/QuotAI/issues/31) and [#55](https://github.com/marotron/QuotAI/issues/55).

## Quiet hours

Settings → Refresh offers quiet hours in a separate group from refresh on wake, off by default, with local start and end times (initially 22:00–07:00). The from/until controls use custom 24-hour hour and minute fields with two-digit formatting and explicit side padding. Each component accepts typing and vertical dragging (up increases, down decreases), clamped to 00–23 hours and 00–59 minutes. The interval includes its start and excludes its end, can cross midnight, and equal times mean no quiet window. Timer-driven polling, including discrepancy-driven polling and usage-threshold polling, pauses during the window. Explicit refresh and the panel's stale-on-open refresh remain available. Refresh on wake is a separate switch, on by default; when enabled it also works during quiet hours. App launch also requests an initial refresh during quiet hours. Both settings explain these exceptions even when switched off. Disabling Refresh on wake skips that wake-triggered request; it does not suppress scheduled polling outside quiet hours. A wake refresh does not disable or change quiet hours, so timer-driven polling remains paused for the rest of the window.

## High-usage rules

Settings offers two opt-in rules: a shared “Cursor Models + Other Models” rule and a separate Grok Bot rule. Either Cursor meter reaching the shared threshold activates its family; activation is retained separately until each triggering meter resets. A rule chooses a threshold from 0–99% and an interval from 1–60 minutes; the initial values are 90% and one minute, with each rule off. The rule label reads “usage at or above”; percentage fields reserve room for two digits; typing, dragging, and saved settings clamp to 0–99%. The percentage and minute fields can be typed or dragged vertically, matching the Dynamic refresh number fields. These are defaults for the controls, not imposed active policies. A successful reading no more than one hour old, with available usage at or above the threshold and a known future reset, activates its rule until that reset. Active state survives restart. A later lower reading does not stop it; a changed reset replaces the old period, and a missing or expired reset cannot activate a new rule. No additional model-specific or five-hour windows are claimed where the current provider data does not expose them.

Confirmed decision, 2026-11-14: the highest applicable refresh rate always wins, meaning the shortest interval between the selected fixed/Dynamic cadence and an active usage rule. A five-minute usage rule plus a one-minute Dynamic cadence refreshes every minute; a one-minute usage rule plus a five-minute Dynamic cadence also refreshes every minute. This is recomputed as reset approaches, so a latched usage rule never prevents Dynamic refresh from accelerating. Dynamic rows retain their existing first-matching-row semantics. Quiet hours and failed-request retry delays remain scheduling gates. Cursor Models and Other Models share one rule and request; either can accelerate that family. Existing separate Cursor rules migrate to one: preserve any enabled rule, or use the lowest threshold and shortest interval if both were enabled; retain Grok independently. Grok is scheduled independently. Normal fixed polling continues to refresh both families together when no threshold rule is active. Quiet hours suppress all timer-driven requests. Manual and menu-open refreshes remain possible. Failed automatic requests wait at least five minutes before another automatic attempt for the affected family, including HTTP rate-limit errors. This is a conservative local retry delay; the client does not currently interpret provider Retry-After headers.

## Settings placement

Decision 2026-11-14: 0.20.0 places refresh status, manual actions, rate and Dynamic schedule, wake, quiet hours, and high-usage rules under Settings → Refresh. Account retains Cursor authentication and activity diagnostics. The split is implemented; running-app layout verification remains pending.

## Acceptance and verification

- [ ] Verify the six tabs and expanded Refresh controls fit and remain usable in the running app; confirm account and refresh errors are visible alongside their respective actions.

- [ ] Configure and persist quiet hours, wake behavior, and family rules; verify controls, typing, and vertical dragging in the app.
- [ ] Test daytime and overnight boundaries, including equal times and local timezone. Automated policy tests cover the boundary arithmetic with a fixed timezone; running-app timezone behavior remains to verify.
- [ ] Verify timer, manual, menu-open, wake and discrepancy-driven paths across quiet hours.
- [x] Verify fastest-rate precedence in the planner: both one-minute/five-minute orderings, Dynamic acceleration while a slower usage rule stays active, and a slower usage rule against fixed polling. Regression coverage: `AutomaticRefreshPolicyTests`.
- [ ] Verify multiple active rules, shared requests, Dynamic and fixed cadences, threshold persistence, corrections, reset rollover and missing or stale data.
- [ ] Verify failed automatic requests respect the retry delay and do not spin; check provider rate-limit behavior.
- [ ] Run `make test` and check the candidate in the running app before marking either issue resolved. `make test` passed on 2026-11-14; running-app checks remain outstanding.

2026-11-14, RC5 interaction verification: the shared native numeric control was exercised in an isolated macOS window using the shipping control source. Upward drag changed 90→94; downward drag returned 94→90; typing and committing 75 preserved both digits; dragging the focused field changed 75→79. Full Settings layout and scheduler acceptance remain separate checks.
