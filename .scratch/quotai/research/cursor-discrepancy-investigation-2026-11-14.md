# Cursor discrepancy investigation — 14 November 2026

Investigated the 15:14 screenshot against local Cursor Agent Host logs, the supplied usage CSV, and copies of QuotAI's saved state. Times below are UTC, also London local time on these dates.

## Conclusion

The latest Gemini warning is a false positive. All three Gemini warnings are own-API-key requests billed directly to Google, as confirmed by the user and CSV. Crucially, each local runtime record also contains `reason: "byok-connect-routed"`. The parser discards that reason. This signal was overlooked in the first investigation pass: the local log does provide explicit own-key routing evidence, so CSV import or a new usage endpoint is not needed to identify these turns.

Saved activity intervals are already up to date in this dataset, but the existing ongoing-turn fix does not address this billing-source blind spot or the asymmetric unbilled matching rule. The current fix is not sufficient to call discrepancy detection reliable.

**User confirmation, later on 14 November:** 6 November / cluster 1 is genuine, not a false positive. Treat it as the positive ground-truth example. The subsequent clusters are suspected false positives; four later events already have specific false-positive explanations and two remain unconfirmed. The earlier interpretation of all 122 residual events as unresolved is superseded. Blanket demotion of no-increase results would lose genuine detections and is not the agreed path.

There are 126 saved events, all `unbilledActivity`: 99 Other Models, 27 Cursor Models. No `unattributedQuotaChange` events remain. A complete replay of all retained Agent Host logs through the current Swift reader/parser/reconciler reproduces all 126 events and extends zero saved activity intervals. Another rescan or merely installing the partial-line fix will not clear these warnings.

## Evidence

| Warnings | Evidence | Finding |
|---|---|---|
| 3 Gemini, 13 Nov at 23:05:22, 23:08:14, 23:22:31 | CSV entries at 23:05:22.720, 23:08:15.109, 23:22:32.185; all `User API Key`, cost `0.00`; runtime log starts precede CSV timestamps by 304–460 ms | Confirmed false positives for missing Cursor quota consumption. The last request also has an explicit turn-failed log record. |
| 1 Auto, 10 Nov at 10:10:40 | Activity continues until 11:50:49.835. Cursor meter rises from 78.12 to 78.1355556 at 11:49:28.073. CSV records an Included Auto request at 11:45:13.111 | Incorrectly unmatched despite an overlapping same-meter increase. Start-only matching is the cause; this does not prove which request contributed how much to that aggregate increase. |
| 1 Auto, 9 Nov at 20:03:18 | CSV Included Auto entry at 20:03:18.799. Flat meter observations at 20:09 and 20:19; next increase observed 20:49, from 76.7088889 to 76.9822222 | The request exists in Cursor's usage record. Meter lag/rounding or quota-exempt behavior remains possible. No per-request quota debit is available to establish a billing discrepancy. |
| 1 Auto, 12 Nov at 22:27:55 | CSV Included Auto entry at 22:27:56.175. Saved meter stays 90.6022222 until the following morning | The usage record exists; cause of flat quota is unresolved. The detector cannot establish missing billing from this alone. |
| 120 warnings, 6 Nov / cluster 1 | 65 saved meter snapshots all show exactly Cursor 60.9266667%, Other 64.4666667%. Warnings span 09:13–20:45. Supplied CSV starts 8 Nov. User subsequently confirms this cluster is genuine | User-confirmed true-positive cluster; preserve detection in regression validation. Further export evidence can explain its cause but is no longer needed to label the cluster as genuine for this investigation. |

## Code causes

1. `CursorActivityParser.classify(modelID:)` infers a quota pool from the model name. `CursorAgentTurn` has no billing-source field. The selected-runtime log payload contains `runtime`, `disposition`, `reason`, conversation/generation IDs, `actionCase`, and `modelId`. All three Gemini starts have `runtime: "connect"`, `disposition: "fallback"`, `reason: "byok-connect-routed"`. The installed Cursor router selects that specific reason when `hasModelCredentials` is true. A `connect` runtime alone is not sufficient evidence; this explicit reason is the useful signal. Do not exclude all Gemini requests or all Connect-runtime turns.
2. `CursorDiscrepancyReconciler` attributes quota increases to unbilled candidates using only `turn.timestamp`. The opposite direction already checks `endedAt` interval overlap. A long turn can explain a bump while still being labeled unbilled.
3. Unbilled warnings become eligible when wall-clock time passes five minutes after the **start** and any earlier snapshot exists. A post-turn, same-meter observation is not required. A standalone Swift reproduction with no subsequent observation still emits a warning. Long-running turns can also be labeled before their observed activity has finished.
4. “No observed increase” is weaker evidence than “activity was not reflected in the meter.” Local runtime selection, cancelled/failed requests, own-key requests, rounding, exemptions, and delayed aggregate reporting need separate treatment. The CSV is a usage record, not a per-request quota debit ledger.

## Recommended path

### First: a focused reliability patch

1. Preserve explicit own-key routing metadata from `reason` (and `connectReason` if needed for refused/rerouted turns). Distinguish external/custom-key activity from model-based quota-pool guesses. Exclude the confirmed Google-key turns from missing-Cursor-quota expectations and do not label them Other Models. Keep them available as neutral diagnostic activity if useful. Unknown or missing metadata must stay unknown; a currently configured key does not establish historical billing mode. Do not create a Gemini model-wide exclusion or hardcode UUIDs.
2. Use active-interval overlap consistently in both matching directions. Add a regression based on the 10 Nov case, retaining meter isolation and the existing finite lag window.
3. Require valid same-meter observations both before the turn and after the latest observed activity plus grace before judging it; absence of observations remains pending/unknown. `endedAt` means last observed log activity, not a verified completion timestamp, so this is a minimum evidence gate, not a proof of finished billing.
4. Preserve genuine no-increase detection, including the user-confirmed 6 November cluster. Use factual wording “No quota increase observed.” The earlier blanket advanced-only recommendation is withdrawn; determine automatic warning eligibility against both true-positive and false-positive examples. Runtime selection alone is not proof of a completed, chargeable request. Preserve the opposite-direction detector's descriptive “quota increased without matching local activity” wording; it also cannot prove unauthorized usage (another device or missing logs can explain it).
5. Backfill routing metadata once for retained UUIDs from available logs, then recompute and replace saved events. Preserve model identity and existing activity end times. Do not clear data as a substitute for fixing inference. Historical turns with unavailable logs remain unknown.

### Verification before shipping

- Parser/store regression: identical Gemini model with BYOK routing versus managed routing is treated differently; missing reasons stay unknown; billing metadata survives reload and rescan.
- Reconciler regression: active turn spans a later charge; wrong meter still does not match; absent/nil post-turn observation stays pending; later observations can resolve status; externally billed activity does not become an unbilled warning.
- UI/notification regression: confirmed genuine no-increase cases are not lost by a blanket filter; known external-key and interval-matching false positives are removed. Resolve the remaining eligibility rule consistently across warning surfaces. Legitimate unexplained quota changes remain visible.
- Replay the frozen real dataset, inspect a fresh running-app refresh, and run `make test` before PR closeout. No extra version bump is needed beyond the prepared 0.19.3 patch version.

### Follow-up evidence, not a release prerequisite

The user confirms 6 November / cluster 1 as genuine. A 6–7 November usage export would still help explain the cause and calibrate the discriminating rule, but is not required to accept the user's cluster label. The 9 and 12 November Auto cases remain suspected false positives, not confirmed: usage entries exist but no per-request quota debit is exposed. Increasing a global timeout or polling faster cannot establish the missing billing facts.

## Candidate replay and feasibility

A temporary copy of the actual Swift reconciler was compiled outside the repo with interval overlap and same-meter before/after observation gates. It produced 125 events instead of 126, eliminating the long Auto turn. Both synthetic reproductions (late charge during active turn and no post-turn observation) dropped from one false warning to zero. Excluding the three independently confirmed external-key turns leaves 122 events: the 120 from 6 November (now user-confirmed genuine) and two suspected false positives from 9 and 12 November. The candidate therefore preserves the confirmed positive cluster while removing four explained false positives. Further work must distinguish the remaining two without hiding genuine cases. These are temporary analysis results, not installed app behavior.

All 126 saved warning UUIDs were found in retained runtime-selection logs: 123 reason `eligible`, 3 reason `byok-connect-routed`. Their action types were 104 user-message turns (including the 3 BYOK), 13 summaries, and 9 background-task completions. Those actions should not automatically be assumed to create individual quota debits.

Local Cursor source corroborates the signal: `/Applications/Cursor.app/Contents/Resources/app/extensions/cursor-agent-host/dist/main.js` contains the router branch `if (hasModelCredentials) ... reason: "byok-connect-routed"` and logs the routing reason with the generation UUID. This is an implementation detail to parse defensively, not a stable public API.

Cursor's current [own-key documentation](https://cursor.com/help/models-and-usage/api-keys) adds a generalization limit: provider model cost is billed directly, but Teams/Enterprise can still apply a Cursor Token Rate to eligible own-key requests. Therefore preserve “external model billing” separately from “provably zero Cursor quota effect.” The user's confirmed Gemini calls and their zero-cost CSV rows support the specific exclusions here; do not generalize a universal no-Cursor-cost rule to every account type.

The repo's standing runtime design remains local logs plus meter history; CSV is research evidence only. This plan needs no CSV import, no key access, and no new remote usage integration. The earlier note that CSV Kind was always Included described a previous sample; this export has three explicit User API Key rows.

## Sources and verification

### RC5 selective acquisition implemented and measured

Following user approval of selective lookups, RC5/build 49 uses the existing token to enrich only unmatched activity. Core planning/correlation and the actual network adapter were tested against a copied real activity store with conversation metadata backfilled from retained logs. No CSV parsing or hardcoded UUID/date exceptions are used by production code.

The planner chose two windows: **15.515 seconds** around the 12 November turn and **6.574 seconds** around the 9 November turn. Each returned one complete record in one request, **488 bytes** each (**976 response-body bytes total**, excluding headers/TLS). Both records were explicitly non-chargeable and uniquely matched the appropriate conversation/model/start. Observed request waits were about **3,371 ms** and **556 ms**; correlation took **5.923 ms** and **1.461 ms**, respectively. These are single-run measurements, not a general latency guarantee.

Reconciliation then changed **122 → 120 warnings**, preserving all 120 on 6 November and removing both Free Auto cases. Planning another check within the ten-minute cooldown returned no windows. The metadata rescan is a separate one-time background migration; network/processing measurements above do not include that rescan. Cache storage is period-scoped and contains only the selected evidence/status, not downloaded response bodies, prompt content or credentials.

Automated tests cover exact boolean parsing, no evidence/ambiguous/conflicting matches, Free then billable retries, finite query coverage, changed activity, batching/window limits, retry backoff, persistence/rollover, bounded pagination and authentication failures. `make test` passed. The actual app was rebuilt and relaunched as RC5; its persisted live state now has **120 events, all 6 November**, and **two nonChargeable billing cache entries**, with conversation backfill complete. Public release/commit/tag are still pending.

Probe source: `/private/tmp/quotai-selective-billing-live.swift`; copied state `/private/tmp/quotai-selective-billing-state.json`. The probe used the compiled QuotAICore plus the unmodified production reader/client adapters, performed read-only service requests, and kept credentials in memory.

### Live access verified: usage records with existing authentication

A read-only live probe has now confirmed acquisition, superseding the earlier protocol-only access uncertainty:

1. Loaded QuotAI's existing access token through Keychain in memory. No token values were printed or saved; no credentials or Keychain entries were changed and no browser cookies were used.
2. Baseline `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage` returned HTTP 200.
3. `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetFilteredUsageEvents`, using the same Bearer token and Connect JSON headers, also returned HTTP 200.
4. Request body used Unix-millisecond string `startDate` / `endDate` for 9 November 19:55–21:10, `page: 1`, `pageSize: 100`, and no team override. Six display records were returned for that interval.

The response uses `model: "default"` for CSV `auto`. The exact records match the export:

| Timestamp (London/UTC) | kind | isChargeable | chargedCents | Token evidence |
|---|---|---|---:|---|
| 20:03:18.799 | INCLUDED_IN_PRO | false | 0 | tokenUsage absent; CSV Free |
| 20:20:15.992 | INCLUDED_IN_PRO | true | 87.55540000000001 | input 116,920; cache read 1,074,688; output 17,395 — matches CSV |
| 20:44:15.627 | INCLUDED_IN_PRO | false | 0 | tokenUsage absent; CSV Free |
| 20:44:41.450 | INCLUDED_IN_PRO | true | 35.9494 | input 37,525; cache read 438,016; output 10,906 — matches CSV |

The returned enum strings include the `USAGE_EVENT_KIND_` prefix. `isChargeable` is a JSON boolean (Foundation's dictionary description prints it as 0/1). Both Free and consuming Included rows have the same kind, confirming that Kind alone is insufficient. The response additionally exposes `conversationId`, `usageEventId`, `cursorTokenFee`, `requestsCosts`, `usageBasedCosts`, and other metadata. Included charged-cost figures describe usage valuation here; they do not imply an additional out-of-pocket invoice.

The automatic fix is now feasible with the existing session on this account: fetch detailed events, correlate conservatively with local activity, and suppress missing-debit expectations only for explicitly non-chargeable matches. Missing `isChargeable`, ambiguous joins, incomplete pagination and fetch failures must remain unknown rather than being interpreted as Free. Cursor's private endpoint is not a public stability guarantee. Integration, request pagination/backfill, correlation and error handling are still pending; this probe did not change application behavior or the local-only runtime specification.

Probe source: `/private/tmp/quotai-usage-access-probe.swift`. Only response schemas and selected billing metadata were inspected; no full response/account IDs were persisted in the repo.

### Automatic fix candidate: per-request billing evidence

Further inspection of the installed Cursor bundle found a concrete candidate beyond local log heuristics. In `/Applications/Cursor.app/Contents/Resources/app/extensions/cursor-agent-host/dist/main.js`, `aiserver.v1.DashboardService` defines `GetFilteredUsageEvents`. Its request supports date bounds, model/user filters and pagination. Its response defines `usage_events`, `usage_events_display` and a total count.

`UsageEventDisplay` includes timestamp, model, kind, optional `is_chargeable`, token usage, optional charged cents, conversation ID and usage event ID. The accompanying `UsageEventKind` enum includes `ABORTED_NOT_CHARGED`, `ERRORED_NOT_CHARGED`, `USER_API_KEY`, and included-plan variants. These are installed protocol declarations, not a verified successful API call. In particular, the meaning/presence of `is_chargeable` must be validated against the actual Free and Included examples before treating it as quota eligibility. Zero charged cents alone cannot distinguish included allowance from free usage.

Recommended implementation direction: add authoritative per-request billing evidence to reconciliation. Validate access with the existing authentication and map responses to the supplied export's exact 20:03 Free / 20:20 Included examples. Suppress missing-debit warnings only for explicitly non-consuming records, retain BYOK handling, and keep Included requests subject to interval matching. Correlate stable identities where exposed; otherwise require unambiguous conversation/model/timestamp associations, without model-wide or date/UUID exceptions. Missing, paginated-away, delayed or ambiguous evidence must not be silently treated as Free. Backfill the active period and recompute derived events.

This extends the current local-logs-plus-meter-history runtime boundary and is a proposed contract change, not implemented or locked by this research note. The exported CSV supplies reference evidence/regression fixtures; a manual CSV import or per-event dismissal is not the recommended final automatic design. Release acceptance must remove the two confirmed Free Auto warnings and preserve detection of the confirmed genuine 6 November cluster; lack of a 6 November usage export must not be interpreted as proof of free usage.

### Follow-up: exact attribution cutoff for 9 November 20:03

Rechecked the live persisted state after the RC4 curve correction. The flagged turn starts at **20:03:18.339**, with last observed activity at **20:03:20.913**. Cursor is still **76.7088888888889%** at **20:09:43.372** and **20:19:09.408**. The next increase is first observed at **20:49:10.077**, to **76.98222222222222%**. This establishes an observation interval for the increase, not an exact billing timestamp.

The matching algorithm's 15-minute plateau lookback is anchored to the preceding observation (20:19:09), giving a lower sampling limit of **20:04:09**. The earliest retained equal reading inside that limit is **20:09:43**. Consequently the effective attribution interval for the 20:49 rise is **20:09:43–20:54:10** (with grace). The 20:03 turn is outside it. The flat 20:09 observation also satisfies post-turn coverage after five-minute grace, so the turn becomes an unbilled candidate before that later rise and remains unmatched afterward.

Ground truth in the supplied export is stronger than a temporal association: **20:03:18.799 Auto is Cost: Free**, with no token quantities. The later **20:20:15.992** and **20:44:41.450** Auto entries have Included cost and 1,209,003 / 486,447 total tokens respectively. Thus the 20:03 warning is a confirmed false positive caused by treating runtime activity as a chargeable request. Widening a time window until it matches the later debit would conceal that billing-classification defect rather than establish that this Free request consumed quota.

Additional local-source check: queried the exact conversation's `composerData` record read-only in Cursor's global `state.vscdb`, avoiding a scan of its roughly 8 GB of unrelated data. The matching metadata record exposes no billing/free/cost fields and does not contain the target generation UUID. No matching home chat directory was found for that conversation ID. This targeted check found no new automatic classifier; it does not claim all Cursor storage formats have been exhaustively decoded. No application behavior, matching tolerance, saved event exclusions, or candidate version was changed in this read-only investigation.

### 16:10 screenshot: hovered date versus discrepancy date

The screenshot's hover reading is 9 November **21:16**, while the attached discrepancy row explicitly refers to **20:03**. These are different clocks: the hover interpolates the series at the pointer, while the discrepancy section shows the nearby cluster's event. For the 20:03 event, Cursor remains **76.7088889%** at 19:55:54, 20:09:43, and 20:19:09. It first rises to **76.9822222%** at 20:49:10, then **77.14%** at 21:00:52 and **77.84%** at 21:30:53. The screenshot's roughly 77.51% at 21:16 is consistent with those later observations/interpolation; it is not evidence of a quota debit for the 20:03 request.

The export marks the 20:03:18.799 Auto request **Free**. Later requests, including 20:20:15.992 and 20:44:41.450, are **Included** with token usage. The later aggregate rise has compatible later activity and does not require widening attribution to the earlier Free request. The warning is still a false positive because chargeability is unknown to the local detector, not because a same-time observed increase was ignored. No production timestamp/model/UUID exclusion has been introduced.

RC3 keeps two-decimal corridor values on one line so the hover surface can size to its actual contents; the screenshot showed **used** wrapping below the numeric threshold and overflowing the background. This revision does not alter matching or hide the remaining Free warnings.

The follow-up screenshots at 16:13:59 and 16:14:09 still show RC2 and hover at 20:11 / 20:21. At 20:11 the raw meter remains 76.7088889%; at 20:21 the chart interpolates between the 20:19 and 20:49 observations. That apparent early rise is not an observed per-request debit at 20:03. RC3/build 47 was subsequently tested (`make test` passed), rebuilt and locally relaunched. Native UI inspection was interrupted; live visual confirmation of the tooltip is still a dogfood check, not claimed as completed.

### RC2: remaining chart clusters and hover precision

The running app was verified as RC1/build 45 with 123 cached warnings; the BYOK backfill had completed. Re-examination of the two remaining short Auto requests (9 Nov 20:03:18 and 12 Nov 22:27:55) found **Cost: Free**, not merely Kind: Included, in the supplied CSV. Both have empty token columns. Their local starts are `userMessageAction`, and both have `Agent client stream abort` records with reason `composer_abort_controller_aborted`. However, this same explicit abort appears on two warnings in the user-confirmed genuine 6 November cluster. Blanket abort or summary exclusions would therefore discard positive examples. No explicit local free/billable flag was found in the inspected Agent Host records. User confirmed the requirement that free calls should not create a quota-increase expectation; a reliable local classifier remains unresolved.

RC2/build 46 adds interval matching and same-meter before/after coverage checks. Full real-data replay now leaves **122 warnings**: all 120 from 6 November plus the two Free Auto calls. The long-running 10 November mismatch resolves. Regression tests pass, including wrong/missing meter observations and late charges during active turns. Hover used-% and corridor used-% values now display exactly two decimals; raw samples and axis formatting are unchanged. The local .build application was rebuilt and relaunched as RC2. This does not constitute a release.

### Implementation replay — exact BYOK reason, 14 November

The user explicitly selected `reason: "byok-connect-routed"` as the detector's outside-Cursor-billing signal. The working-tree implementation persists this reason, backfills it once by UUID from retained logs, and excludes exact matches from both matching directions. Other/missing reasons do not trigger exclusion. Failed scans/saves keep the routing backfill retryable. Existing events are recomputed rather than hardcoded away.

Recompiled the actual core and reader after this change and replayed the frozen dataset: **126 → 123 warnings**, exactly three outside-Cursor turns detected from local reasons, **all 120 genuine 6 November warnings preserved**. Three Auto warnings remain (9, 10 and 12 November); interval/coverage changes are separate pending work. This is distinct from the earlier temporary candidate that also applied interval changes and left 122 events.

`make test` passes with six new billing-routing regressions covering exact reason detection, monotonic backfill/continuation, both reconciliation directions, legacy cache migration/reload/event replacement, failed enumeration, and failed migration persistence. This verifies working-tree code, not an installed/released build.

- Supplied CSV: `/Users/marotron/Downloads/usage-events-2026-11-14.csv` — 3,923 rows, 8 Nov 07:45:13.698 through 14 Nov 14:59:31.319; 3 User API Key rows, all Gemini, and 3,920 Included rows.
- Screenshot: `/Users/marotron/Desktop/Screenshot 2026-11-14 at 15.14.00.png`.
- Saved state copied from `~/Library/Application Support/dev.marotron.QuotAI/{cursor-activity,pace-history}.json`: 1,673 turns, 2,768 snapshots, 26 persisted log offsets; latest observation 14 Nov 15:11:51.196596. Both backfill flags already true.
- Agent Host logs under `~/Library/Application Support/Cursor/logs`, including the Gemini records in `20261113T130932/window3/exthost/anysphere.cursor-agent-host/Cursor Agent Host.log`.
- Raw state copies and diagnostic scripts/executable are local in `/private/tmp/quotai-discrepancy-review`, `/private/tmp/quotai-discrepancy-replay`, and `/private/tmp/quotai-discrepancy-*.py`. Raw logs, prompts, credentials, and CSV contents were not added to the repository or sent to GitHub.
- Compiled the actual Swift reader/parser/reconciler with a standalone harness, replayed all retained logs, and reproduced 126 warnings. Separately reproduced start-only matching on a long active turn and premature warning with no post-turn observations.
- Production code and live app caches were not changed during this investigation. Earlier uncommitted partial-line/save-order fixes remain in the working tree.
