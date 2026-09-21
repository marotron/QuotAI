# Tech specs — QuotAI

Last updated: 2026-09-20

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
| Smart pace alert bands | pure | `PaceAlertBands` straight-line over/under corridors |
| Alert decision | pure | `PaceAlertDecision` meters + channels → blink/notify/email + signature |
| Alert cooldown | pure | `PaceAlertCooldown` edge + cooldown suppress |
| Alert message builder | pure | `AlertMessageBuilder` subject/body |
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
