# Product requirements — QuotAI

Last updated: 2026-11-14

## Authority and status

This is the application-wide product specification. [Tech specs](tech-specs.md) define implementation boundaries; the [Cursor discrepancy contract](cursor-discrepancies.md) defines detailed diagnostic rules. Historical tickets and research explain decisions but do not override these contracts.

The baseline below describes the 0.19.3 release. Further discrepancy warning-policy refinements remain open in the detailed contract.

## Goal

macOS menu-bar app for understanding Cursor Spending quota, time to reset, and consumption pace, with optional local activity diagnostics. Quota and billing periods come from Cursor's services; local activity counts do not reconstruct billing.

## Meters and presentation — existing baseline

- **Meters:** Cursor Models, optional Other Models, and Grok Bot. Cursor Models and Other share a billing cycle; Grok has its own reported start/reset.
- **Menu bar:** bars, individual quota rings, nested Cursor rings, or pace segments; configurable labels, ring center content, and colors. Nested Cursor alternates Models and Other; corridor alerts can blink the affected ring.
- **Window panel:** used %, elapsed %, neutral pace %, corridor status, reset time, pace-history chart, and actions. Menu pins choose action/display rows; Compact uses two columns and Normal one.
- **Actions:** Refresh all / Cursor / Grok Bot, Settings, About, Quit, and **Open Cursor Spending** → `https://cursor.com/dashboard/spending`.
- **Unavailable data:** never fabricate a zero. Missing Grok does not make a valid Cursor meter unavailable. Transient refresh failures retain prior values and show error/freshness information.
- **About:** version, short commit SHA, embedded changelog, and release links; panel version opens the changelog. The panel version text aligns with the right edge of the meter text, including on hover (2026-11-14; visual verification pending).

## Authentication and secrets — existing baseline

- Hybrid capture: auto-read Cursor `state.vscdb`, else paste.
- Keychain SoT: service `dev.marotron.QuotAI`, account `default`, JSON `{accessToken, refreshToken}`, `AfterFirstUnlockThisDeviceOnly`.
- Fail: one DB re-import → quiet menu **Re-auth from Cursor** / **Paste token…** / **Open Cursor Spending**.
- No auth-failure notifications.
- Provider API keys and prompt content are not needed for discrepancy analysis.

## Refresh and history — existing baseline

- Fixed polling offers 5 / 10 / 15 / 30 / 60 minutes, default 10. Dynamic refresh applies one configurable schedule independently to Cursor (Models + Other) and Grok from each family's reset time. Fixed polling refreshes both together.
- Manual family refreshes, refresh on wake, and panel-open refresh when stale are supported. Last successful refresh and freshness are shown per family in 24-hour time.
- Successful updates append local history samples, not one sample per day. Each meter's series rolls when its reported period start changes.
- The chart plots used % against elapsed %, with meter colors, corridor bands, hover details, series filters, and session-only X zoom up to ×10. Hover quota readings and used-% corridor boundaries show exactly two decimal places (for example `95.24% used`); main meter rows and axis ticks keep compact formatting. Closing the panel resets zoom; chart downsampling does not change stored samples.
- Version 0.20.0 adds optional quiet hours and high-usage refresh rules; see [automatic refresh](automatic-refresh.md) for decisions and acceptance status. The highest applicable refresh rate (shortest interval) wins between the selected fixed/Dynamic cadence and an active usage rule: five minutes versus one minute means one minute. Quiet hours and error retry delays still apply. Running-app acceptance remains incomplete.

## Pace and corridor alerts — existing baseline

- Pace ratio is `r = percentUsed / (100 × elapsedFraction)`, with the existing early-period clamp. Panel pace text is a neutral percentage; missing period information yields unavailable pace.
- Ratio and corridor significance are separate. Corridors on the used/elapsed plane determine quiet / under / over / exhausted; the old ratio dead zone is not the chrome rule.
- Cursor Models and Other share a corridor profile; Grok has its own. In by-level color mode, quiet/alerts-off is neutral, under blue, over orange, exhausted red; blink is configurable. [Pace chrome](pace-chrome.md) is the detailed color/blink contract.
- Blink, notification, and email use corridor significance; notification/email apply cooldown and de-duplication. Discrepancy notifications are separate.
- The surplus/deficit pace redesign remains undecided; it is not adopted by this specification.

## Cursor activity diagnostics — 0.19.3

The [Cursor discrepancy contract](cursor-discrepancies.md) is normative for this feature.

- Detection is optional, using local Agent Host logs and Cursor Models / Other meter history for the current Cursor billing period. As agreed on 2026-11-14, RC5 adds selective read-only Cursor billing-event lookups for unmatched activity, using the existing session. CSV exports remain research evidence only, not a runtime import.
- Model identity, provider billing source, and Cursor quota eligibility are separate facts. Preserve explicit own-key routing rather than deciding billing from model name alone.
- By user decision, exact `reason: "byok-connect-routed"` marks a turn outside Cursor billing and excludes it from Cursor discrepancy matching in both directions. The confirmed Google-key Gemini calls are therefore external activity, not unbilled Other Models activity. This is per-turn routing, not a model-wide exclusion or an account-pricing inference. A one-time retained-log migration recovers the reason for historical activity.
- Use same-meter activity intervals consistently. Judging missing increases requires valid observations before and after activity plus grace; five minutes passing alone is insufficient.
- Unknown billing eligibility and missing observations remain unknown or pending. Runtime selection does not prove a completed, chargeable request.
- Explicitly non-chargeable billing evidence removes the corresponding missing-increase warning. The association must be unique by conversation, model and time; a Free first attempt followed by a chargeable retry must not suppress the whole turn. Unavailable/ambiguous evidence never means Free and does not erase existing genuine discrepancies.
- Billing checks run in the background only when unmatched activity needs verification. Cache results for the active period, batch nearby requests, cap requests/pagination, and throttle retries. Detection off means no billing lookups. See the detail contract for the resource limits.
- After adequate observations, unexplained flat-meter activity may be genuine: the user confirms 6 November / cluster 1 as a true positive. Use **No quota increase observed** as factual wording, preserve genuine detection, and do not blanket-suppress this direction. The automatic warning/notification eligibility rule for these cases remains unresolved, superseding the earlier advanced-only policy.
- A meter increase lacking a local match can be shown as **Quota increased without matching local activity**. This does not prove unauthorized usage; other devices or missing logs can explain it.
- Only warning-eligible results feed the main notice, warning chart marks, and discrepancy notifications. External activity without a verified Cursor debit expectation and cases without observation coverage are excluded. The remaining eligibility policy must distinguish known genuine cases from later false positives before release.
- Migrate retained activity and recompute results to remove obsolete warnings without discarding quota history or inventing historical billing facts.

Activity-interval matching requires valid same-meter readings before activity and after its latest observation plus grace. Unmatched warnings retain the legacy presentation; broader eligibility and wording remain open for future work. Explicitly free calls do not create missing-quota expectations; neither a summary action nor cancellation alone proves a call free.

## Settings, distribution, and scope

Settings cover account/auth, refresh, display, menu pins/density, pace alerts, and optional discrepancy detection/notifications. Distribution is GitHub Releases with DMGs and manual updates; builds are ad-hoc signed unless signing/notarization is configured. See [CI/CD](agents/ci-cd.md).

Decision 2026-11-14, 0.20.0: Settings separates **Account** (Cursor authentication, spending link, and activity diagnostics) from **Refresh** (status, manual refresh, cadence, and automatic refresh policies). The implementation is pending running-app layout verification; see [automatic refresh](automatic-refresh.md).

- xAI Management API
- Extending AIMonitor
- Non-macOS
- Single Cursor account; macOS 14+ and native Swift only. Multi-account, App Store distribution, and official API migration remain roadmap work.
- Perplexity/OpenAI providers, model catalog, custom notification chrome, quiet hours, usage-threshold refresh, and a new pace metric are separate proposals, not baseline functionality.

## PoC learnings

See [`.scratch/quotai/issues/05-throwaway-poc.md`](../.scratch/quotai/issues/05-throwaway-poc.md). Connect + Desktop tokens work on this machine. Production path: Keychain + vscdb import + Connect refresh in the Swift app.

## Keeping the contract current

RC3 tooltip refinement: two-decimal corridor readings remain single-line, and all hover content must fit inside the content-sized surface, including when a discrepancy row is present. This is a layout refinement, not a change to meter values or matching.

Chart precision: zoomed trajectories use original visible readings, preserve every change in slope without a point-budget/Y-rounding approximation, and use linear interpolation consistent with hover values. Exactly collinear points may be omitted without changing the line. As of 0.20.0 (2026-11-14), hover markers are 25% opaque (75% transparent). Values between refresh samples remain interpolated estimates, not additional observations; overview smoothing/downsampling remains display-only.

Version lifecycle follows the shared RC-first policy (adopted from MailGent on 2026-11-14). Product work opens the next numeric marketing version as `X.Y.Z-rc.1`; candidate updates increment RC and build together. About/panel display RC identity, while the public README stays on the shipped release and candidate notes stay under Unreleased. Authorized ship clears RC to 0, increments build, promotes dated notes and updates public documentation. The policy was first applied to `0.19.3-rc.1` (build 45), followed by the `0.19.3` release (build 50). See [the repo adapter](../.cursor/rules/versioning.mdc).

Behavior changes update this specification and the relevant technical/detail contract in the same change set. Record decision dates and implementation status. Release notes record shipped changes; research/issues retain evidence and history. Changes to locked requirements must be recorded explicitly rather than silently substituting current implementation behavior.
