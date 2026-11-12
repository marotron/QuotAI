# Tech specs — QuotAI

Last updated: 2026-11-04

## Stack

- macOS 14+, Swift, SwiftUI `MenuBarExtra`, XcodeGen
- Bundle id prefix: `dev.marotron.QuotAI`
- `LSUIElement` menu-bar app (no Dock icon)

## Fetch

- Primary: Connect Bearer
  - `POST …/GetCurrentPeriodUsage` → Cursor Models `autoPercentUsed`, cycle bounds
  - `POST …/GetSandUsageStatus` → Grok `usagePercent`, reset/start when present
- Refresh: `POST …/oauth/token` with documented Cursor client id
- Optional later: cookie REST fallbacks (`usage-summary`, sand REST)

## Secrets

- Runtime: Keychain only (see `docs/pr.md`)
- Import: read-only SQLite `state.vscdb` ItemTable keys `cursorAuth/accessToken`, `cursorAuth/refreshToken`

## TDD seams (v1 + v0.4 alerts)

| Seam | Kind | Notes |
|------|------|--------|
| Quota response parsing | pure | Map Connect JSON → domain meters; missing Grok → unavailable |
| Burn-rate / pace | pure | `PaceCalculator` from locked formula |
| Menu presentation model | pure | Map meters + settings → bar title / dropdown rows |
| Menu pin layout | pure | `MenuPinLayout.sections(isOn:)` — pinned rows grouped in `MenuPinGroup` order, empty groups hidden; `MenuPinDensity` columns (Compact 2, Normal 1) ([`MenuPinLayoutTests`](../QuotAICore/Tests/MenuPinLayoutTests.swift)) |
| Smart pace alert bands | pure | `PaceAlertBands` over/under corridors; curve dials linear→parabolic (under mirrors across even pace; clamp to endpoint parallels). Cursor default `25/95/25/95/0/0`; Grok seed `35/85/40/90/20/20` |
| Alert family | pure | `PaceAlertFamily` — `cursor`/`other` share Cursor profile; `grok` has its own |
| Alert thresholds store | pure | `PaceAlertThresholdStore` — Cursor legacy keys + `grok*` keys |
| Period duration tips | pure | `PeriodDuration` — live `periodEnd − periodStart` for Settings badge / dial / chart tips |
| Alert decision | pure | `PaceAlertDecision` meters + per-family thresholds + channels → blink/notify/email + signature |
| Alert cooldown | pure | `PaceAlertCooldown` edge + cooldown suppress |
| Pace chrome | pure | `PaceChromeResolver` — corridor under/over/exhausted tint + blink; quiet / alerts-off → neutral ([docs/pace-chrome.md](pace-chrome.md)) |
| Alert message builder | pure | `AlertMessageBuilder` subject/body |
| Dynamic refresh schedule | pure | `RefreshSchedule.interval(periodEnds:now:)` — per-family period ends, first step strictly under the threshold; bad or duplicate JSON → default |
| Per-meter refresh planner | pure | `RefreshPlanner` due families + next fire from shared schedule/fixed minutes and dual last-fetch times |
| Last refresh status line | pure | `LastRefreshStatus.line` — `Last refresh: Cursor {HH:mm} · Grok Bot {HH:mm}` (24-hour; `—` when nil) |
| Cursor activity parser | pure | `CursorActivityParser` reads selected Agent Host runtime records, validates payloads, de-duplicates `generationUUID` values, and sets optional `endedAt` from later log lines that mention the same UUID |
| Cursor discrepancy reconciler | pure | `CursorDiscrepancyReconciler` matches local turns to same-meter quota increases within a five-minute grace window (a meter increase counts as unattributed only if no same-meter turn’s active interval overlaps the bump’s explain window: start through `endedAt` or start, with a 20-minute lookback), then emits unbilled / unattributed events with stable notification signatures |
| Cursor activity store | pure persistence | `CursorActivityStore` JSON state for the current Cursor billing period only: turns, meter snapshots, and discrepancy events; a new `periodStart` clears and reseeds it |
| Network + Keychain + SMTP + UserNotifications | untested | Thin adapters |

## Modules (initial)

- `QuotAICore` — pure parse + pace + presentation + alert seams (unit-tested)
- `QuotAI` app — MenuBarExtra, Settings, Keychain, `state.vscdb` import, Connect `URLSession`, notifications/email adapters, open Spending URL

## Live fetch (app adapters)

- Keychain SoT → if empty, one-time import from Cursor `state.vscdb`
- Connect: `GetCurrentPeriodUsage` + `GetSandUsageStatus`; oauth refresh on 401
- Auth fail → one DB re-import, then quiet menu recovery (Re-auth / Paste / Open Spending)
- Pace: one UserDefaults sample per meter per local day; live `%` / days on every refresh
- Manual **Refresh** in menu (background poll still fog)
- On successful refresh → `PaceAlertOrchestrator` (decision → cooldown → notify/email)
- Optional Cursor discrepancy detection reads local `Cursor Agent Host*.log` records incrementally. While a recent turn is inside the five-minute grace window, Cursor meter refreshes are temporarily limited to roughly one minute; detector state is retained for the active billing period only. Pace chart Discrepancies bands/strip cluster both unbilled activity and unattributed meter bumps; the panel notice shows the latest event with full date and time.
