# Cursor activity diagnostics contract

Decision date: 2026-11-14
Status: **0.19.3 implementation locked and verified; further warning-policy refinements remain open**

RC5 decision, 2026-11-14: user approved selective automatic billing lookups after live access was verified. This explicitly extends the former local-only runtime boundary. `GetFilteredUsageEvents` supplies chargeability evidence for unmatched local turns, with the bounds and matching rules below. The user accepted the result for 0.19.3. Historical statements below about a missing local signal describe earlier revisions, not the current acquisition path.

RC5 verification: automated tests and a live run of the actual planner/client/correlation code passed. Two narrow requests returned 976 response-body bytes, correctly classified the two Free Auto turns, and reduced 122 warnings to the 120 confirmed 6 November warnings. Correlation took about 7 ms total in the probe; network waits were about four seconds and ran in the background. The running RC5/build 49 app subsequently persisted the same result, with two non-chargeable cache entries. The initial conversation-metadata backfill is one-time background work; these measurements describe the billing requests/correlation, not the cost of that historical log rescan.

Follow-up decision, 2026-11-14: the user confirms **6 November / cluster 1 is genuine**, not a false positive. Preserving detection of that cluster is an acceptance requirement. The earlier blanket rule relegating all adequately observed no-increase cases to advanced diagnostics is withdrawn; automatic warning eligibility for these cases remains **unresolved**. Routing, interval, and observation requirements remain locked.

Implementation update, 2026-11-14: user explicitly selects the exact `reason: "byok-connect-routed"` field as the outside-Cursor-billing signal. Parser/store/reader/reconciler support, one-time routing backfill, and interval/observation changes are implemented; broader warning-policy refinements remain open.

Verification of that subset: `make test` passes, including six routing/migration regressions. Real-data Swift replay produces 123 warnings instead of 126, removes all three Gemini BYOK warnings, and retains all 120 user-confirmed 6 November warnings. The three later Auto cases remain for separate matching/observation work. Live UI acceptance and release are still pending.

This is the detailed contract referenced by [product requirements](pr.md) and [tech specs](tech-specs.md). It supersedes the legacy inference that every selected model must produce a quota increase within five minutes. The [investigation](../.scratch/quotai/research/cursor-discrepancy-investigation-2026-11-14.md) records evidence, not additional runtime requirements.

## Purpose and evidence boundaries

RC2 follow-up: explicitly free usage must not create a quota-debit expectation (user confirmed, 2026-11-14). The two remaining Auto export entries are `Cost: Free`, with empty token columns, but both local starts are `userMessageAction`. Aborts also occur in two confirmed genuine 6 November cases, and summary actions occur in that genuine cluster. Do not equate all summaries or aborts with free requests. A reliable per-request local free/billable signal is still needed; no blanket exclusion or date/UUID exception is authorized.

RC2 verification: `make test` passes with interval and observation regressions. Real-data replay retains all 120 6 November warnings and removes the 10 November interval mismatch, leaving the two exported Free Auto calls. RC2/build 46 has been rebuilt and locally relaunched; automatic exclusion of Free requests remains blocked by the missing reliable local signal, not by the interval change. Tooltip used readings and corridor thresholds show two decimals.

Compare local Cursor activity with observed Cursor Models / Other quota changes. Explain uncertainty without claiming to audit provider invoices or prove unauthorized usage. Grok Bot is outside this detector.

Runtime inputs are local Agent Host logs, fetched quota snapshots, current-period pace history, and selective detailed billing events from Cursor's `DashboardService/GetFilteredUsageEvents`, using the existing Bearer session. CSV exports are research aids only; provider keys, prompt content, browser cookies and CSV imports are not needed.

## Selective billing contract — RC5

- Look up only current-period `unbilledActivity` candidates that have local conversation/model identity and need verification. Do not query all history on startup or every meter refresh. Turns longer than the bounded window remain unverified rather than being partially classified.
- Plan at most **two windows per ten minutes**, batch nearby turns within five minutes into windows no longer than **one hour**, and pad observed intervals by **two seconds** to accommodate the observed log/event timestamp offset.
- Fetch at most **two pages of 100 records per window**, with a **10-second request timeout** and a **1 MiB response validation limit**. Maximum production work is four requests per ten-minute lookup pass. Incomplete pagination, malformed/oversized responses, duplicate pages and failures cannot prove Free.
- Correlate using the same nonempty conversation ID, exact normalized model (`default` → `auto` only), and an event within two seconds of the turn start. Examine the full observed activity interval, not just the first event. Require unique record ownership among retained turns. Unknown flags, conflicting records, missing identity and ambiguous matches remain unknown.
- Exclude a turn from quota discrepancy matching only when a complete covered query establishes that every associated event is explicitly `isChargeable: false`. Any chargeable retry prevents Free classification. Neither zero monetary cost nor absent tokens implies Free.
- Cache terminal chargeable/non-chargeable evidence and stable event IDs by local UUID for the current period. New activity beyond the checked interval invalidates that evidence. Cache unknown results for ten minutes while recent, then 24 hours for older activity. Persist the global lookup timestamp so network failures/relaunches cannot create a tight retry loop. Period rollover clears billing checks/throttle with other period-scoped data.
- Backfill conversation IDs once from retained runtime records alongside routing evidence; missing logs remain unknown. No source data or per-date/model/UUID exception is injected to remove particular warnings.
- Run requests, parsing and correlation off the main actor. Serialize detector passes, and discard late results if detection is disabled or the active period changes. Billing enrichment must never fail quota refresh or trigger extra auth re-import/token rotation. Cached evidence is applied before deriving charts/notification candidates so confirmed Free warnings disappear consistently.
- Preserve other matching/observation rules and genuine detections. This change does not blanket-hide unmatched activity whose chargeability is unknown.

## Per-turn facts

Keep the generation UUID, start timestamp, latest observed activity, original model identity, and explicit routing evidence separately from any inferred quota pool.

- `reason: "byok-connect-routed"` is the authoritative per-turn signal for outside-Cursor-billing usage in this detector, by explicit user decision. Preserve `reason` per turn and exclude exact matches from both debit expectations and explanations of Cursor meter increases. Other reason values, the runtime field, model name, and current settings must not substitute for this exact signal. `connectReason` alone is not used by the implemented rule.
- A model name or `runtime: "connect"` alone does not prove own-key billing. A currently configured provider key does not establish historical routing. Missing/unrecognized evidence remains unknown.
- Provider billing source and Cursor quota eligibility are distinct. The confirmed Google-key Gemini calls must not be labeled unbilled Other Models activity. Do not blanket-exclude Gemini or all Connect-runtime calls.
- [Cursor own-key documentation](https://cursor.com/help/models-and-usage/api-keys) describes plan-dependent fees. That general billing context does not override the user's selected detector rule for explicit `byok-connect-routed` turns. QuotAI does not infer account pricing, scrape pricing pages, or make provider-invoice claims.
- Retain the local model ID; the existing `default` → `auto` rewrite is allowed. Do not enrich ambiguous variants via timestamp joins.
- Runtime selection is evidence of activity, not proof of request success or chargeability. Summaries, background actions, failed/cancelled turns and partial execution cannot each be assumed to create a debit.
- Existing `endedAt` means **latest observed activity**, not confirmed completion. A nil value represents no later known activity; it does not establish an instantaneous completed request.

## Matching and observation rules

1. Use same-meter activity interval overlap in both attribution directions, from start to latest observed activity (start alone if none is known). One turn may explain multiple aggregate increases. Association does not prove an individual debit amount.
2. Keep finite matching tolerances: five-minute grace, 15-minute plateau lookback, and 20-minute unattributed lookback are the baseline. This change does not authorize unlimited temporal matching or time-window increases to make warnings disappear.
3. Before judging a missing increase, require a valid observation for the same meter at/before the turn and another at/after latest observed activity plus grace. Wall-clock passage, a snapshot for the wrong meter, or a nil reading does not satisfy coverage.
4. Without coverage, retain pending/unknown status. A completed observation window is a minimum evidence gate, not proof of completion or missing billing. Flat aggregate readings can reflect rounding, exemptions, reporting lag, or stale upstream data.
5. Preserve meter isolation: an Other Models increase cannot settle a Cursor Models expectation. For external/unknown quota eligibility, do not manufacture a pool assignment. Such activity may remain contextual evidence without proving or disproving a particular pool change.

## Result and presentation policy

These are semantic outcomes, not a requirement for a particular enum/schema design.

| Outcome | Meaning | UI / notification policy |
|---|---|---|
| Matched activity | An appropriate observed increase overlaps activity | No discrepancy warning; retain evidence for diagnostics |
| External/custom-key activity | Exact `reason: "byok-connect-routed"` | Excluded from Cursor discrepancy matching in both directions; may appear as neutral external activity, never automatically under Other Models |
| Verified Free activity | Complete, unambiguous billing query establishes non-chargeable activity throughout the checked interval | Excluded from discrepancy matching, chart warnings and notifications; evidence cached for the active period |
| Pending observations | Inadequate same-meter before/after observation coverage | No primary warning, warning marks, warning count, or notification |
| Unknown billing lookup | Missing, failed, ambiguous or incomplete billing enrichment | Does not prove Free or erase an otherwise eligible existing diagnostic; existing matching/observation policy applies |
| No quota increase observed | Adequate coverage, but no explainable increase; may be a genuine discrepancy or an inference error | Use this factual wording. Preserve genuine cases such as 6 November; do not blanket-suppress. Automatic warning/notification eligibility needs a discriminating rule and remains unresolved |
| Quota increased without matching local activity | Observed increase with no compatible local explanation within the finite window | Warning-eligible descriptive result; can feed the notice, chart and opt-in notifications, without implying unauthorized usage |

Only warning-eligible results are clustered into warning chart bands/strip and selected for the primary notice. External activity without a verified Cursor debit expectation and cases lacking observation coverage are not warning-eligible. Adequately observed no-increase cases must not all be discarded as noise: the dataset includes a confirmed genuine cluster. Their automatic eligibility policy must be resolved against both positive and negative examples before release. When no eligible results remain, the old warning/marks clear. Existing advanced-list layout can be reused; this contract does not require a new screen or manual confirmation feature.

Discrepancy delivery is separate from corridor blink/notify/email. Respect detection and discrepancy-notification settings, evaluate current eligibility before delivery, and preserve stable de-duplication for unchanged eligible results. Reconciliation/migration must not notify about removed or downgraded historical warnings. It cannot retract notifications already delivered by macOS.

## Persistence, migration, and ingestion

- Retain only the active Cursor billing period's turns, snapshots, and results; roll them when the reported period start changes. Preserve file cursors and completed format migration flags as appropriate.
- Decode older state without inventing missing routing evidence. Backfill routing metadata once from retained runtime records using generation UUIDs. Preserve original starts, model identity, and the longest known activity interval. Missing logs leave historical provenance unknown.
- Backfill success must reflect completed reads; temporary file/read/save failures must remain retryable rather than permanently marking absent evidence as established.
- Recompute and replace derived results so obsolete unbilled warnings disappear. Re-evaluate notification candidates from the new result policy. Do not delete meter history or silently hardcode UUID/model exclusions to clear the UI.
- Incremental reading must carry known turns across chunks/relaunches, extend activity monotonically, consume complete log records only, retry unfinished/UTF-8-split lines, and handle truncation. Save activity before advancing its cursor so replay after an interrupted write is safe.
- Scan off the main actor; a detector/cache failure must not block quota refresh or authentication. Faster polling is an observation optimization, not a change to evidence requirements.

## Acceptance checks before marking implemented

- [x] Selective planner performs no work without unmatched activity, respects cooldown/window limits, batches nearby activity and uses cached results across relaunches.
- [x] Explicit billing booleans are parsed without treating a missing flag, zero price or empty tokens as Free. Incomplete/ambiguous/conflicting records stay unknown; a chargeable retry prevents whole-turn exclusion.
- [x] Billing evidence persists per period, invalidates when activity extends, and clears at period rollover. Conversation IDs survive parsing/normalization/reload.
- [x] Network tests verify at most two pages per window and no automatic retry on authentication failure. Real-data selective probe and live app remove both Free warnings and preserve all 120 genuine 6 November warnings.

- [x] Same model with explicit own-key routing versus other/missing reasons produces distinct evidence; `connect` alone is not classified as external. Automated regression included in 0.19.3.
- [x] Routing metadata persists across refresh/reload and backfills by UUID from old state without shortening activity; failed scans/saves keep migration retryable. Automated reader/store regression included in 0.19.3. Missing retained records leave unknown metadata.
- [ ] A long turn overlapping a later same-meter increase is matched; later increases during that interval do not create contradictory unbilled status. Wrong-meter increases remain isolated.
- [x] Missing/nil/wrong-meter post-turn readings remain pending even after wall-clock grace passes; a later valid observation can resolve the status. Implemented with RC2 regression tests; not released.
- [x] Exact BYOK turns neither create missing-debit warnings nor explain Cursor quota increases; otherwise identical Gemini turns remain in normal matching. Automated regression included in 0.19.3.
- [ ] Resolve automatic warning eligibility for adequately observed no-increase activity using confirmed genuine 6 November cases and later false-positive examples. Do not simply suppress this entire detection direction. Main notice, chart bands/strip, counts and notifications must share the resulting policy.
- [ ] Eligible unexplained quota increases remain visible; identical warning results do not repeatedly notify. Recomputing removes obsolete warnings without notifying about them.
- [ ] Reader tests cover relaunch, incomplete records/split UTF-8, truncation, monotonic intervals and safe persistence ordering where practical.
- [ ] Replay the frozen investigation dataset: retain 6 November / cluster 1 as the user-confirmed positive case; recognize the three own-key calls locally and resolve the 10 November long-turn mismatch. The 9 and 12 November Auto cases remain suspected false positives, not confirmed. Do not hardcode dates, model names or UUIDs into production rules to reproduce the labels.
- [ ] `make test` passes and a fresh running-app refresh verifies warning/advanced-list/notification behavior. Record implementation evidence before changing this document's pending status.

## Decision history

2026-11-14: Investigation found 126 legacy unbilled events: three confirmed Google-key requests, one interval-matching error, and 122 unresolved flat-meter cases. Local routing reasons make own-key recognition feasible without changing the runtime data-source boundary. User requested that the revised behavior be saved and locked in the application specifications. This contract records that target; investigation replay counts do not establish future live provider behavior.

2026-11-14 follow-up: user confirms 6 November / cluster 1 as genuine. Ground-truth breakdown is now 120 warnings in a user-confirmed genuine cluster, four established later false positives (three own-key and one interval mismatch), and two later Auto cases the user suspects are false positives. This supersedes the earlier “122 unresolved” interpretation and the blanket advanced-only policy for all no-increase results. Preserve both the positive and negative examples in validation; the remaining classification rule is an open design question.
