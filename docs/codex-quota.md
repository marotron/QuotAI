# Codex subscription quota

Decisions: 2026-11-14. Status: **0.21.0 implementation; acceptance incomplete**. This contract supports [OpenAI usage and quota tracker](https://github.com/marotron/QuotAI/issues/54). Release verification and live account acceptance are tracked below.

## Experimental 5h→7d ratio (0.24.0)

Decision 2026-11-17: an opt-in experimental tracker records each closed ≈5-hour Codex window and estimates what full 5h usage would imply as a share of the ≈7-day meter. Settings → Account → Codex offers **Track Codex 5h→7d ratio (experimental)** (default off). Observation runs after successful quota reads while the toggle is on. A period opens only after short-window used % > 0 (Codex starts the 5h window on first use); idle floating `resetsAt` values do not open or close records. When an opened short window’s `resetsAt` changes, one record is appended to `codex-5h-weekly-ratio.json` (genuine samples stay forever; on load, idle `peakZero` / peak ≤ 0 artifacts are purged). Disconnect or turning the toggle off stops new records; history stays. Windows are selected by duration, not slot. Implied % is omitted when the weekly reset changes mid-period, usage is missing, or peak 5h usage is ≤0. The list lives in the pace-chart Advanced popover under **Codex 5h→7d** (tab beside cluster-based Discrepancies). Clicking a row highlights that 5h slice as a teal band on the chart when it maps onto the live Codex ≈7d window. No live meter-row chip, notifications, delete UI, or chart→list reverse click. Detail: [`.scratch/codex-5h-weekly-ratio/spec.md`](../.scratch/codex-5h-weekly-ratio/spec.md).

## Scope and display

Codex is optional and off by default. Settings → Account provides Enable Codex quota, browser sign-in, disconnect and an optional menu-bar display. No Codex installation, helper download, API key or existing Codex credential import is required. A separate Keychain item owns this integration's credentials.

The dropdown shows every returned primary/secondary quota window for each reported bucket. Window duration and labels come from the provider; five-hour and weekly labels are not assumed. Decision 2026-11-15: each returned Codex window follows the shared Display settings for bars or rings, color mode, beside icon, used percentage, elapsed/reset labels and alternation, and ring center. The user-supplied OpenAI knot identifies Codex in the menu bar and panel (decision 2026-11-15). The knot inside a ring is drawn at 50% opacity, with a 0.7 pt inset from the innermost ring (updated 2026-11-15 from 0.5 pt); beside-ring and panel icons keep their existing opacity. Windows remain separate because their periods differ; Cursor's Models/Other nesting and Show Other Models affect Cursor only. Codex uses the shared Cursor corridor thresholds for pace tint and significant blink when those settings are enabled; this extends the previous locked decision that excluded Codex pace chrome. No Codex notifications or email are added. Candidate 0.22.0 records Codex pace history on successful quota reads, keeping each reported window distinct and rolling its history when its period changes; a successful new sign-in and disconnect clear Codex history. Existing Cursor and Grok history is preserved. Core persistence, filtering, rollover and legacy ID tests pass; seeded native chart and avatar-solo preview were checked. Live account/reset acceptance remains pending. When a future reset and valid duration are available, elapsed is clamped from `1 − (reset − now) / duration`; otherwise no elapsed timeline is drawn and pace rings use a neutral usage arc. Expired resets show ↻. Stale Codex images are dimmed. Codex images must be upright, with elapsed arcs starting at 12 o’clock and progressing clockwise. The rc.4 compositing correction was checked with an asymmetric AppKit image; running-app display verification is pending.

Usage of zero is a real reading. Missing/invalid usage, duration or reset stays unavailable; it never becomes zero or an invented period. An expired reset shows “Reset passed · awaiting refresh”; the clock does not manufacture renewed quota or backend permission. Decision 2026-11-16: if included usage is explicitly blocked, omit the separate notice when an ordinary Codex window reports at least 100% used; otherwise show it below the chart, after the Cursor discrepancy notice when present, in the shared discrepancy notice chrome (icon / title / when / body). An exhausted additional bucket does not explain the ordinary-usage block. Status: verified in the seeded native preview; live account acceptance remains pending. Credit balances are not converted into quota percentages.

Decision 2026-11-17: transient refresh failures (offline and similar) keep previous readings and surface **one** below-chart notice in that same chrome, naming the providers that failed. Do not show separate top-of-panel or above-chart orange strings for the same event. Age badges and Refresh all use amber warning chrome only for failed providers; those meters dim. Codex sign-in errors stay with the sign-in controls. Status: candidate implementation; live offline acceptance pending.

Transient errors keep the previous readings and show provider-local error/freshness information; stale readings are dimmed. A successful new sign-in clears previous readings and trigger state before reading the selected account. A returned account ID that disagrees with the authenticated account is rejected. Codex errors do not replace Cursor's authentication state or prevent Cursor/Grok refreshes.

## Native sign-in and secrets

The implementation uses the public native Codex client's OAuth parameters and an internal HTTP quota route, following [pinned upstream source](https://github.com/openai/codex/tree/d32063f96c2dff1dc96af839b3952abb6acfeda4). This is an unofficial direct integration; live success on one account does not establish an independently supported quota API or universal plan eligibility.

Browser sign-in uses PKCE S256, fresh state/nonce, a loopback-only listener on upstream-supported port 1455 (1457 fallback), and identity/offline scopes without connector permissions. The callback validates host, path, state and unique query parameters. Requests are bounded; sign-in times out after five minutes and can be cancelled. Code exchange is never blindly retried. Identity-token RS256 signature, issuer, audience, expiration and nonce are validated against OpenAI signing keys before account routing is used. Federal routing is unavailable in this first version.

Tokens are stored only in macOS Keychain, service `dev.marotron.QuotAI`, account `codex-oauth`, accessibility `AfterFirstUnlockThisDeviceOnly`. Neither the Cursor item nor another Codex installation's credentials are read or changed. Disconnect deletes QuotAI's local item and clears displayed data/active rules; it does not revoke or sign out another Codex application.

Refresh is serialized by the Codex store. A near-expiry token is refreshed before reading; an unexpected 401 can trigger at most one refresh/read retry. Rotated credentials replace the Keychain record together. Refreshed identity, when supplied, must match the previous verified account and subject. Failed Keychain access never falls back to a credential file. Ephemeral URLSession networking has no cookie cache or automatic redirects. Errors never log raw responses, callback queries, tokens or authorization headers.

## Refresh rules

Codex uses QuotAI's shared one-shot RunLoop timer. Fixed/Dynamic settings determine its normal cadence; Dynamic uses its reported reset times. One request serves all Codex buckets/windows. Explicit Refresh Codex, Refresh all, launch, enabled refresh-on-wake and stale panel-open refreshes can read during quiet hours, matching the existing refresh contract. Quiet hours suppress all automatic Codex polling. Disabled or disconnected Codex makes no quota requests.

Settings → Refresh provides an opt-in high-usage rule per returned window in “Refresh faster at high usage”, below Grok, using the same controls as the other providers (decision 2026-11-15; running-app acceptance pending). Each rule accepts a threshold of 0–99% and interval of 1–60 minutes; initial controls are off, 90%, one minute. Values clamp on editing/loading. A successful reading no more than one hour old, at/above threshold with a known future reset, activates the rule until that reset. A lower corrected reading does not clear it. A changed reset releases the old trigger; missing/stale data cannot activate a new trigger. Editing a rule clears and reevaluates its trigger. Active end times persist across restart and are cleared on disconnect/new sign-in.

The shortest interval wins across normal cadence and active window rules; shared reads are not duplicated per window. Failed requests wait at least five minutes before another automatic attempt. Expired/rejected authentication stops automatic reads and offers sign-in. Manual/menu-open paths remain deliberate exceptions to automatic retry gating, as with existing providers.

## Acceptance evidence

- [x] Candidate 0.22.0-rc.8: `make test` passed on 2026-11-16, covering a blocked response with exhausted, non-exhausted, missing and additional-bucket windows.
- [x] Seeded native preview on 2026-11-16 showed the unexplained block below the chart and hid it when the Codex window reached 100%. Source layout places the notice after any discrepancy; live account verification remains pending.

- [x] Native Swift feasibility probe completed browser OAuth, verified ID-token signature/identity, and read real quota without a model call or helper. On 2026-11-14 the test account returned 64% used in a 300-minute window and 28% in a 10080-minute window. The 217,456-byte executable discarded credentials on exit.
- [x] Probe callback checks exercised loopback binding, unrelated paths, mismatched state, duplicate parameters and a valid callback. Offline checks covered PKCE, zero usage, missing windows, account mismatch and redacted output.
- [x] `CodexQuotaTests` cover multiple buckets/windows, unknown values, invalid readings, duplicate identity, independent trigger latches, corrections, persistence, shortest-interval precedence, rollover and stale/reset-missing data. Final `make test` passed on 2026-11-14 after the candidate source edits.
- [x] Check the candidate dropdown, Account and Refresh settings in the running app. The dropdown showed separate 5h/7d rows, countdowns and `0.21.0-rc.1`; manual refresh advanced the last-read time. Editing the 5h threshold from 90 to 95 worked; it was restored to 90 and off. Separate menu-bar ring rendering still needs visual confirmation outside the panel screenshot.
- [ ] Complete candidate sign-in and verify the Keychain-owned read, relaunch, refresh rotation and disconnect without changing an independent Codex login.

Candidate Account was observed signed in with both windows loaded, demonstrating the Keychain-save-before-read path succeeded. Relaunch/rotation/disconnect checks remain outstanding; do not treat the in-memory probe as evidence for them. The macOS application-menu About action is routed to QuotAI's existing custom About window so it uses the same RC identity as the panel.

The complete local Debug app bundle measured approximately 11.74 MB after native integration (not a release DMG size or measured size delta). It contains no app-server binary or downloaded Codex runtime.
- [ ] Verify quiet hours, wake, launch, panel-open/manual requests, shared reads, automatic retry delay and disabled behavior in the running candidate.
- [ ] Verify rate-limit errors, account switching, expired authentication and provider response changes in integration scenarios.

The research/probe supports this contract but does not replace these candidate acceptance checks. See [research](../.scratch/quotai/research/openai-quota-sources-2026-11-14.md) and [probe](../.scratch/openai-quota/direct-swift-spike/README.md).

## Display acceptance (2026-11-15)

- [ ] With Codex enabled, switch each menu-bar style and color mode; Codex follows the chosen style and color behavior.
- [ ] Toggle beside icons, used %, elapsed/reset and alternating labels; Codex responds in sync with other meters.
- [ ] Select None, Icon and Time to reset for ring center; Codex displays the corresponding content.
- [ ] Verify unavailable/expired reset and stale states without inventing elapsed time.

- [ ] Verify the supplied OpenAI logo is upright and legible in Codex ring centers, beside meters and in the panel under both color modes.

- [ ] Verify center icons have 50% opacity for one-per-meter, nested, pace and Codex rings, while beside icons and time-to-reset text are unchanged.

- [ ] Verify the selected Cursor 0.55 pt, Grok 0.6 pt and Codex 0.7 pt center insets at 50% icon opacity. Perplexity 1 pt is a prototype-only target until that provider exists.

- [ ] With labels and icons off, verify Cursor, Grok and Codex dials have the same small gaps; also check labels and the Cursor authentication-error state.

## Exploratory panel matrix (2026-11-15)

Decision 2026-11-15: the user approved the matrix and compact refresh header in `.scratch/quotai/window-prototypes/experiments/codex-matrix/index.html?matrix=1`. Codex rows use shared used ÷ elapsed = pace, corridor status and reset columns. Missing inputs show dashes; expired resets show Reset passed and do not manufacture a new window. Provider badges refresh their provider, the left control refreshes all, and hover/focus uses white on blue. The version and refresh icon align by content edges. Perplexity is a prototype-only placeholder until integrated. On 2026-11-15 the seeded native panel preview was visually checked in light and dark, with both Codex rows and the three-provider refresh header visible. Native corridor thresholds govern status; in the seeded 37% used / 15% elapsed example, the prototype’s illustrative over icon differs from the native on-corridor result. Individual/all live refresh and missing, expired, sign-in and error states remain pending acceptance.

- [ ] Verify the native panel against the approved prototype, including light/dark appearance, individual and all-provider refresh, missing and expired data, and sign-in/error states.


Decision 2026-11-15: Codex quota windows follow the same history chart and avatar filter behavior as Cursor and Grok; use each returned window’s actual reset and duration, omit samples without valid usage or a future reset, and avoid mixing history between accounts. Status: candidate implementation verified with core tests and a seeded native preview; live acceptance remains pending.

- [ ] Verify separate Codex windows, reset rollover, account changes and persistence without affecting Cursor or Grok.
- [ ] Verify chart lines, hover tips and avatar filtering in the native dropdown.

- [x] Candidate 0.22.0-rc.1: `make test` passed, including Codex window persistence, rollover, filtering, legacy IDs and isolated history removal; the seeded native panel showed both Codex lines and the 5h avatar solo filter.
