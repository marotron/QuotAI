# Alarm corridors vs. period length (Cursor monthly vs Grok Bot window)

Research only. No Swift source was modified. Repo state read: `QuotAICore/Sources/*`, `QuotAI/*`, `.scratch/quotai/*`, `docs/*`, `CHANGELOG.md`.

Legend: **PROVEN** = read directly in code/tests. **DOCUMENTED** = stated in repo notes (sourced from third parties). **SUSPECTED** = not in repo evidence.

## TL;DR

- Cursor Models and Other Models: period is `billingCycleStart` → `billingCycleEnd` from the API (monthly). PROVEN. **Do not assume 31 days** — calendar months are 28 / 29 / 30 / 31; day/hour dial captions and chart tips must use the live `end − start` duration (same as Grok).
- Grok Bot: period is `currentPeriodStart` → `nextResetTimestampUtc` from the API; **no hard-coded length anywhere**. Repo notes call it "weekly" (7 days). PROVEN (no constant) / DOCUMENTED (weekly).
- **Live local pace history (2026-11-09, this Mac):** inferred period length Cursor/Other **31.00 d**, Grok **3.10 d** (12 Grok samples, stable). PROVEN for this account; not hard-coded in app source. Public/third-party docs still say weekly. Cursor’s 31.00 d here is one billing month only.
- Alert corridors are **fraction-of-period-elapsed** (`t = elapsed / total`). Period length never enters the alert math. Shipped direction: **per-family** `%` profiles — Cursor (Models + Other) vs Grok Bot (`PaceAlertFamily` / `PaceAlertThresholdStore`); Settings Alerts segment edits the focused profile. Menu pace history still paints the Cursor corridor only until a later focus/zoom pass.
- Day/hour tips and the Settings period badge use live `periodEnd − periodStart` (`PeriodDuration`) — never a hard-coded 31d or weekly window.

## 1. Period start/end parsing

File: `QuotAICore/Sources/QuotaResponseParser.swift`

| Meter | Function | Start field | End field | Percent field |
|---|---|---|---|---|
| Cursor Models | `cursorModels` → `periodMeter` | `billingCycleStart` | `billingCycleEnd` | `planUsage.autoPercentUsed` |
| Other Models | `otherModels` → `periodMeter` | `billingCycleStart` | `billingCycleEnd` | `planUsage.apiPercentUsed` |
| Grok Bot | `grokBot` | `currentPeriodStart` | `nextResetTimestampUtc` | `usagePercent` |

Key code:

```swift
// periodMeter (Cursor + Other share one billing cycle)
let start = parseTimestamp(root["billingCycleStart"])
let end = parseTimestamp(root["billingCycleEnd"])
```

```swift
// grokBot
let start = parseTimestamp(root["currentPeriodStart"])
let end = parseTimestamp(root["nextResetTimestampUtc"])
```

- `parseTimestamp` accepts unix ms/seconds (number or digit string; `> 1e12` → ms) or ISO-8601. PROVEN.
- Cursor and Other share the same cycle (same response). PROVEN.
- If start or end is missing, `pace` becomes `"Pace n/a"` and `PaceAlertOrchestrator.meterInput` returns `nil` (meter skipped for alerts). PROVEN.
- Grok is `isUnavailable` unless `usagePercent` exists, not pooled enterprise, not `includedLimitZero`, and `hasNonZeroIncludedLimit`. PROVEN.
- **No code derives a window length** (no `7 * 86_400`, no start+N days fallback). Grok test fixture uses `start = now - 2d`, `end = now + 5d` (a 7-day span) in `QuotaResponseParserTests.testParsesEligibleGrokBot`. That is a test fixture, not evidence of live data.
- Live-sample values: `cursor-spending-fetch.md` shows only a Cursor cycle example (`1768399334000` → `1771077734000` = 31 days). No raw Grok JSON payload is checked into the repo; see §2.1 for inferred live lengths from Application Support pace history.

## 2. Documented / suspected Grok window length

Primary notes: `.scratch/quotai/research/cursor-spending-fetch.md`

- Line 5: "Cursor Models (monthly) and Grok Bot (weekly)".
- Line 33: "Grok Bot has a **separate weekly** included allowance".
- Lines 160–166: `nextResetTimestampUtc` "often **missing**"; `currentPeriodStart`: "Do **not** invent reset as start+7d (Pulse: vendor client does not)". OpenUsage PR #1134 uses "period length from start→reset or fallback week duration for UI math".
- `issues/02-research-cursor-spending-fetch.md` line 22: "inventing reset from start+7d is wrong".
- Also "weekly" in `issues/01-name-the-meters.md`, `.scratch/quotai/map.md`, discrepancy-marks prototype DESIGN.md.
- `CHANGELOG.md`: no statement of Grok window length (Grok appears only in refresh/UI/pace-history items).
- `docs/`: no Grok window length.

Status:
- "Weekly / 7 days": DOCUMENTED (third-party sources: cursor.com/help/grok-bot/plans wording, OpenUsage, Pulse). Not verified by a captured raw JSON payload in this repo.
- "~3 days" on this account: **PROVEN by inference** from local pace history (see §2.1). Not present as a constant in app source; public docs still say weekly.
- Implication: QuotAI adapts automatically as long as the API returns both timestamps (no hard-coded 7). Missing `nextResetTimestampUtc` would drop Grok out of alerts (meter returns nil) rather than guess.

### 2.1 Live local inference (2026-11-09)

Source: `~/Library/Application Support/dev.marotron.QuotAI/pace-history.json` (not committed). Samples store `periodStart`, `elapsedPct`, `timestamp` (no `periodEnd`). Period length inferred as:

`duration = (timestamp − periodStart) / (elapsedPct / 100)`

| Meter | Samples used | Inferred period |
|---|---|---|
| `cursor` / `other` | latest samples | **31.00 d** |
| `grok` | all 12 samples that day | **3.099 d** (stable to 4 decimals across samples) |

Grok `periodStart` on that day: `2026-11-09T06:39:28Z`. Example mid-morning: ~25% used at ~5.5% elapsed (~4 h into the window) → heavily over even pace. Optional follow-up: capture one raw `GetSandUsageStatus` body with `currentPeriodStart` / `nextResetTimestampUtc` to confirm without inference.

**Product rule (Settings day captions / dial tips):** both families read period length from the live API timestamps. Cursor can be 28–31 days depending on the billing month; never bake “≈ 31 d” into UI copy or defaults that pretend the month length is fixed.

## 3. Pace math (elapsed %, not absolute days)

### Elapsed fraction (`QuotAICore/Sources/PaceCalculator.swift`)

```swift
let total = periodEnd.timeIntervalSince(periodStart)
let epsilon = total / (24 * 30)          // "≈ one hour on a ~30-day period"
let elapsed = max(now.timeIntervalSince(periodStart), epsilon)
return min(max(elapsed / total, 1e-6), 1.0)
```

Note: epsilon is `total/720`, so it scales with period. On a 30-day cycle ≈ 1 h; on a 7-day Grok window ≈ 14 min; on 3 days ≈ 6 min. Floor on `t` is therefore ~0.139% for every meter. PROVEN.

Pace ratio: `r = (percentUsed/100) / t`. Legacy ratio bands: `greenLo = 0.90`, `greenHi = 1.10`, `significantLo = 0.75`, `significantHi = 1.30`.

`daysToExhaustion` is the only absolute-days quantity: `burn = percentUsed / daysElapsed`, `(100 - percentUsed) / burn`. It feeds label text ("empties in ~…") and `isEarly`, **not** the corridor decision. PROVEN.

### Smart corridors (`QuotAICore/Sources/PaceAlertBands.swift`)

Defaults (`PaceAlertThresholds.default`): `overMaxStartPct 25`, `overEmptyBeforePct 95`, `underAfterPct 25`, `underMinEndPct 95`, `overCurvePct 0`, `underCurvePct 0`. Header comment: "Locked endpoint defaults: 25 / 95 / 25 / 95. Curve dials default 0 = linear."

With `u = percentUsed/100`, `t = elapsedFraction` (clamped `[1e-6, 1]`), `a=0.25`, `b=0.95`, `c=0.25`, `d=0.95`, `p = 1 + clamp(curvePct/100, 0, 1)`:

- `u >= 1` → `.exhausted`.
- Over line: `overUsed(t) = max( a + (1−a)·(t/b)^p , t + (1−b) )`. Linear default: from (0, 25%) to (95%, 100%); floor is the parallel of even pace `u = t + 0.05`. Over if `u > overLine`.
- Under line (only when `t > c`): `underUsed(t) = min( d·((t−c)/(1−c))^(1/p) , t + (d−1) )`. Linear default: from (25%, 0) to (100%, 95%); ceiling is `u = t − 0.05`. Under if `u < underLine`.
- Legacy (smart off): `r = u/t`; under if `r < 0.75`, over if `r > 1.30` (defaults from `blinkUnderPercent 75` / `blinkOverPercent 130`).

Consequence: a corridor point means "X% of the allowance used at Y% of the period". The same used/elapsed point alerts identically on a 31-day Cursor cycle and a 7-day (or 3-day) Grok window. Wall-clock slack differs wildly though:

| Period | 25% elapsed (over/under start gate) | 5% elapsed-wide slack (`1−b`, `d−1`) |
|---|---|---|
| 31 d | ≈ 7.75 d | ≈ 1.55 d |
| 7 d | ≈ 1.75 d | ≈ 8.4 h |
| 3 d | ≈ 18 h | ≈ 3.6 h |

(Derived arithmetic; not in repo.) So for a short window the "quiet" start period and the tolerance at the end both shrink in absolute time while usage noise (a few heavy Grok sessions) is relatively larger → more false over/under flips. This is an inference, not measured.

## 4. Global vs per-meter settings

PROVEN global, one corridor for all meters:

- `PaceAlertOrchestrator.handleSuccessfulRefresh` builds a single `PaceAlertThresholds` from `UserDefaults` keys `overMaxStartPct`, `overEmptyBeforePct`, `underAfterPct`, `underMinEndPct`, `overCurvePct`, `underCurvePct` and passes it to `PaceAlertDecision.evaluate(meters:…)` for `cursor`, `other`, `grok` inputs.
- `PaceAlertDecision.evaluate` maps each `PaceAlertMeterInput(id,name,percentUsed,elapsedFraction)` through the same `thresholds`. No per-meter parameter exists.
- Same single `smartThresholds` for UI: `QuotAIApp.swift` (`smartThresholds`, `@AppStorage("overMaxStartPct")` …), `SettingsView.swift`, `MenuBarWindowPanel.swift` (`smartThresholds`), `PaceAlertBandChart.swift`, `PaceHistoryChart.swift` (`thresholds`).
- Other global toggles: `useSmartPaceAlerts`, `blinkUnderPercent`, `blinkOverPercent`, channel toggles (`blinkSignificantPace`, `notifySignificantPace`, `emailSignificantPace`), cooldown `3600` s (one signature across all meters).
- The only per-meter pieces are refresh cadence (`RefreshPlanner`, issue 18 "Per-meter Dynamic refresh") and pace history samples (`PaceHistorySampleStore`, series `cursor`/`other`/`grok`). Neither affects corridors.
- Pace history chart plots all meters against **normalized elapsed %** with the same corridor boundaries (CHANGELOG 0.15.0 notes; `issues/13-pace-history-trajectories.md` line 46). Normalization is what makes a monthly and a weekly series overlap on one X axis.

## 5. Prior discussion of separate corridors / day-based thresholds

Searched `per-meter`, `separate corrid`, `day-based`, `days-based`, `absolute day`, `3/7 days`, `weekly`, `corridor` across the repo (excluding `.pbxproj`). Findings:

- **No** issue, note, comment, test, or CHANGELOG line proposes per-meter corridors, per-period-length scaling, or day-based thresholds.
- "per-meter" hits are about refresh (issue 18), pace samples (issue 04, 09), and ring layout (`MenuOptionTitles`).
- `docs/pace-chrome.md` states chrome uses "same corridors as the pace history chart" and one corridor kind per meter; says nothing about period length.
- `issues/04-burn-rate-formula.md` is the closest prior art: locked ratio formula + one sample per meter per local day (stored `periodEnd`). It treats days only as a display/projection quantity.

## 6. Strategic implications

1. **Percent-elapsed corridors are period-agnostic by design, so a Grok window change (7 → 3 days) needs no parser or alert code change**, provided the API keeps returning `currentPeriodStart` + `nextResetTimestampUtc`. The risk is semantic, not mechanical: the same 25/95/25/95 corridor means 1.75 d of "quiet start" on 7 d but ~18 h on 3 d.
2. **One global corridor mis-fits mixed periods.** Short windows (Grok) have a smaller wall-clock "quiet start" and end tolerance, but are fed by bursty sessions; Cursor monthly is smoother. Expect more Grok-driven notifications/blinks, and since cooldown is a single signature across meters (`paceAlertLastSignature`) Grok flapping can also suppress or mask Cursor alerts within the hour. Options (not decided): per-meter threshold sets, or period-length-aware defaults (e.g., minimum quiet-start in absolute time such as `max(25%, X hours/total)`), keeping percent-elapsed as the core model.
3. **Window length on this account is ~3.1 d (inferred).** Raw JSON capture is still useful as a non-inferred cross-check (`GetSandUsageStatus` via `.scratch/quotai/poc/fetch_meters.py`). Missing-reset cases still silently disable Grok alerts today (`meterInput` returns `nil`). Product direction: keep `%` corridors; add Cursor vs Grok threshold profiles (see plan `alarm_corridor_strategy`) rather than switching the engine to absolute days.

## Evidence index

- `QuotAICore/Sources/QuotaResponseParser.swift` — period parsing
- `QuotAICore/Sources/PaceCalculator.swift` — `elapsedFraction`, ratio constants, days-to-exhaustion
- `QuotAICore/Sources/PaceAlertBands.swift` — defaults + corridor math
- `QuotAICore/Sources/PaceAlertDecision.swift` — per-meter inputs, single `thresholds`
- `QuotAI/PaceAlertOrchestrator.swift` — global UserDefaults keys, cooldown `3600`
- `QuotAICore/Tests/QuotaResponseParserTests.swift` — Grok fixture (7-day span, synthetic)
- `.scratch/quotai/research/cursor-spending-fetch.md` — Grok weekly / reset caveats
- `.scratch/quotai/issues/02-research-cursor-spending-fetch.md`, `issues/04-burn-rate-formula.md`, `issues/13-pace-history-trajectories.md`, `issues/18-per-meter-dynamic-refresh.md`
- `docs/pace-chrome.md`, `docs/tech-specs.md`, `CHANGELOG.md`
