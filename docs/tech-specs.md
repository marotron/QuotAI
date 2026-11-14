# Tech specs — QuotAI

Last updated: 2026-11-14

## Authority and status

Read with [product requirements](pr.md). The [Cursor discrepancy contract](cursor-discrepancies.md) records the verified 0.19.3 behavior and separately identifies open warning-policy questions.

## Stack

- macOS 14+, Swift 5.10 project settings, SwiftUI/AppKit menu-bar window panel, Swift Charts, XcodeGen
- Bundle id prefix: `dev.marotron.QuotAI`
- `LSUIElement` menu-bar app (no Dock icon)

## Fetch

- Primary: Connect Bearer
  - `POST …/GetCurrentPeriodUsage` → `planUsage.autoPercentUsed` for Cursor Models, `planUsage.apiPercentUsed` for Other Models, `billingCycleStart` / `billingCycleEnd`
  - `POST …/GetSandUsageStatus` → Grok `usagePercent`, reset/start when present
- Refresh: `POST …/oauth/token` with documented Cursor client id
- Scopes: all / Cursor / Grok. Missing Other yields unavailable; missing required Cursor usage is a parse error. Grok eligibility checks can yield unavailable instead of zero.
- Cookie REST fallbacks are not an implemented runtime path.

## Secrets

- Runtime: Keychain only (see `docs/pr.md`)
- Import: read-only SQLite `state.vscdb` ItemTable keys `cursorAuth/accessToken`, `cursorAuth/refreshToken`

## Verification seams

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
| History / chart model / filtering / downsampling / zoom / tips | pure + persistence | Preserve source samples independently of rendering; period rollover, series filtering, session zoom math and hover content |
| Cursor activity parser | pure | Runtime records → UUID/start/model, conversation/routing evidence and latest observed activity (`endedAt`); evidence survives incremental merges |
| Cursor log reader | filesystem | Test real incremental byte offsets, continuation after relaunch, incomplete lines, and truncation; app reader compiled into core test target |
| Cursor discrepancy reconciler | pure | Five-minute grace, 15-minute plateau lookback and 20-minute unattributed lookback; interval matching, observation coverage and verified billing exclusions |
| Cursor activity store | persistence | Current-period turns, snapshots, events and billing checks/throttle; period rollover preserves log offsets/backfill flags and clears period-scoped evidence |
| Selective billing planner/parser/correlation/client | pure + network adapter | Bounded windows/pages, cache/throttle/backoff, explicit chargeability, unique associations, full-interval coverage and retry-safe behavior; URLProtocol exercises the adapter |
| Discrepancy snapshots / clustering | pure | Backfill Cursor/Other snapshots from history; cluster warning-eligible results only under the target contract |
| Network + Keychain + SMTP + UserNotifications / app UI | integration/manual | Thin adapters; unit tests do not establish live provider behavior or visual correctness |

## Modules

- `QuotAICore` — pure parse + pace + presentation + alert seams (unit-tested)
- `QuotAI` app — menu-bar window panel, Settings/About, Keychain, `state.vscdb` import, Connect `URLSession`, local log reader, notifications/email adapters, open Spending URL
- `QuotAIPanelPreview` — separate target with seeded meters and temporary stores; does not write production history. `.scratch/` prototypes are not production dependencies.
- `project.yml` defines targets/settings. `make project` regenerates the Xcode project; `make test` regenerates then tests the QuotAI scheme.

## Live fetch (app adapters)

- Keychain SoT → if empty, one-time import from Cursor `state.vscdb`
- Connect: `GetCurrentPeriodUsage` + `GetSandUsageStatus`; oauth refresh on 401
- Auth fail → one DB re-import, then quiet menu recovery (Re-auth / Paste / Open Spending)
- History: append every successful meter sample; live `%` / time to reset on each update. JSON history, not a daily UserDefaults sample.
- Manual Refresh all / Cursor / Grok, fixed polling (default 10 min; 5/10/15/30/60 choices), independent per-family dynamic scheduling, wake refresh, and panel-open refresh when stale
- On successful refresh → `PaceAlertOrchestrator` (decision → cooldown → notify/email)
- Optional discrepancy detection reads local `Cursor Agent Host*.log` incrementally off the main actor, using saved offsets and known turns. Recent starts shorten planned Cursor polling to roughly one minute during grace; cadence does not prove billability. Verified Free and BYOK turns are filtered before warning surfaces are updated.

## Refresh, history, and pace details

`QuotaStore` coordinates fetch application, history writes, rescheduling, alerts, and background reconciliation. RunLoop timers/wake handling drive polling; clock updates retune schedules without themselves fetching. `RefreshPlanner` tracks Cursor and Grok separately; fixed mode refreshes both.

Default dynamic schedule: reset strictly under 1 h → every 1 min; under 3 h → 5 min; under 6 h → 10 min; under 12 h → 15 min; under 24 h → 30 min; otherwise 60 min. Invalid stored schedules revert to defaults.

History/diagnostic files are `~/Library/Application Support/dev.marotron.QuotAI/pace-history.json` and `cursor-activity.json`. `PaceHistorySampleStore` stores meter ID, raw used/elapsed %, observation timestamp, and period start. A changed period start clears that meter's old series. Activity state retains only the active Cursor period; log offsets and completed format migrations survive rollover. Credentials remain in Keychain and settings in UserDefaults.

`PaceCalculator` computes `(used / 100) / t`; elapsed duration has an early clamp of `periodDuration / (24 × 30)` and the fraction is capped at 1. Used ≥100 is exhausted; invalid period data yields unavailable pace. Panel ratio text is neutral. Corridor geometry separately drives significance; Cursor/Other share one profile and Grok another.

Chart downsampling/zoom do not rewrite stored samples. X zoom is session-only, capped at ×10, retained across history remounts and cleared on panel close. Each family's corridor is drawn separately. See [pace chrome](pace-chrome.md) for colors/blink.

## Discrepancy reliability

The normative [detail contract](cursor-discrepancies.md) requires per-turn routing evidence, separate quota eligibility, interval matching, observation coverage and persistence/presentation migration. RC5 extends the runtime boundary, with user approval, to selective `GetFilteredUsageEvents` requests for unmatched activity. No CSV import is added. `CursorUsageBilling` provides pure planning/parsing/correlation, and `CursorUsageBillingClient` is the bounded async adapter. The store persists per-turn evidence and a lookup throttle; local conversation IDs are backfilled once. The detector serializes passes and filters explicitly non-chargeable turns before chart/notification results are published. Resource limits, retry/cache rules and ambiguity behavior are normative in the detail contract.

Follow-up ground truth: 6 November / cluster 1 is user-confirmed genuine. Replay validation must preserve that positive case while removing known later false positives. Blanket suppression of adequately observed no-increase results is withdrawn; their automatic warning eligibility remains unresolved in the detail contract. Do not encode dataset dates/UUIDs as runtime exceptions.

Parser/store types retain optional `routingReason`; exact `byok-connect-routed` sets `isOutsideCursorBilling`. Parser, reader and store merges retain that evidence and preserve longer activity intervals. Normalization retains routing metadata. Reconciliation filters external turns in both directions; recent-turn polling acceleration also ignores them. Legacy caches decode with unknown reasons and trigger one retained-log rescan through `didBackfillBillingRouting`. The flag is saved only after successful enumeration/reads and persistence; failed scans/saves remain retryable. Replacing reconciled events removes stale BYOK warnings. This behavior is included in 0.19.3.

Active-interval overlap is used in both matching directions. Missing-increase eligibility requires valid same-meter readings at/before the start and at/after latest observed activity plus grace, and elapsed wall-clock grace. `endedAt` remains latest observed activity, not verified completion. Verified non-chargeable usage is excluded; broader warning wording remains open. Cancellation/action type alone is not a safe billing classifier. Hover used-% readings and corridor thresholds use fixed two-decimal formatting; source data is unchanged.

The reader processes complete lines and saves activity before offsets. Migration associates metadata with retained UUIDs, preserves longer activity intervals, and recomputes replaceable events to remove obsolete warnings.

## Release and specification maintenance

RC4 zoom geometry uses `PaceHistoryChartDownsample.zoomSamples` to crop source readings with context on either side and remove only exactly collinear middle points. No LTTB limit or Y quantization applies while zoomed; quota series marks use `.linear` to match `PaceHistoryInterpolation`. Overview marks retain their reduced/smoothed rendering. Hover PointMarks use 0.5 color opacity. Regression checks compare zoom geometry to raw values, including between samples and beyond the former 200-point budget.

The shared `release-versioning` skill defines the RC-first lifecycle; [the local adapter](../.cursor/rules/versioning.mdc) maps it to QuotAI. `project.yml` holds numeric marketing version, build, and `INFOPLIST_KEY_QuotAIReleaseCandidate`. `ReleaseVersion.label` formats the RC suffix for About/panel, leaving Apple's bundle short version numeric. The changelog parser renders Unreleased alongside historical dated entries. Tagged packaging requires candidate 0 and a matching plain `vX.Y.Z`; release CI skips prerelease tags. Candidate adoption is working-tree code, not a release.

PR/main run `make test`; signed `v*` tags run test → DMG → release. See [CI/CD](agents/ci-cd.md) and repository versioning rules.

Update product/technical/detail contracts in the same change set as behavior changes. Keep agreed targets marked pending until acceptance checks pass. Research supports the contract; it is not an alternate specification. Documentation-only changes need no app version bump.
