# OpenAI quota support: first implementation brief

Date: 2026-11-14
Status: 0.21.0-rc.1 implementation; native live access verified, candidate acceptance incomplete
Issue: [#54](https://github.com/marotron/QuotAI/issues/54)
Evidence: [source investigation](../quotai/research/openai-quota-sources-2026-11-14.md)

This brief supports the application contracts in [product requirements](../../docs/pr.md) and [tech specs](../../docs/tech-specs.md). Only the confirmed planning decisions below are agreed; the remaining proposals do not change existing behavior.

## Planning decisions

Confirmed with the user on 2026-11-14; implemented in the candidate, with acceptance tracked in [the detailed contract](../../docs/codex-quota.md):

- **Scope:** Codex subscription allowance. API spending is outside this effort.
- **Surfaces:** dropdown plus optional menu-bar display.
- **Windows:** show all available quota windows in the dropdown and separate indicators per reported window in the menu bar. Quota-only ring indicators use provider-reported durations and the existing used-percent/time-to-reset preferences; visual verification is recorded in the detailed contract.
- **Setup:** work without a separate Codex installation. Direct native Swift sign-in/networking is selected; no helper or CLI is required.
- **First-version features:** quota usage and reset times. Pace and history are deferred.
- **Refresh:** include configurable, opt-in high-usage refresh rules for Codex windows, subject to quiet hours and failed-request retry limits. One provider read serves the returned windows; acceptance checks cover rule persistence and shared scheduling.
- **Notifications:** display quota status only in the first version; quota notifications are deferred. This is separate from the accepted faster-refresh rules.
- **Size preference:** the user wants a smaller solution than the measured 88 MB download / 218 MB app-server binary. The user selected the direct Swift integration. Native OAuth plus the internal usage read succeeded on the test account; broader account/refresh/error coverage remains pending.

## Proposed first slice

The confirmed scope is **Codex subscription quota**, labelled explicitly as Codex. Proposed presentation: show the usage percentage, duration and next reset for each returned quota window. Preserve the provider's bucket identity and optional label; do not assume that primary always means five hours or secondary always means a week.

The agreed surfaces are a dropdown section showing all available quota windows and an optional menu-bar display with separate indicators per reported window. Exact visual treatment and customization remain undecided. Proposed data handling: retain nullable values as unknown. Credit balances, if exposed, are a separate quantity and must not be presented as a percentage quota. Broader ChatGPT message/tool limits and API organization spending need separate sources and are outside this proposed first slice.

## Native feasibility and implementation

The user selected **Direct Swift integration** after reviewing the small native option versus a custom/full helper. The earlier helper-delivery question is superseded; neither bundling nor a first-use helper download is selected.

The live in-memory Swift probe completed browser OAuth, verified the ID-token signature/issuer/audience/nonce/expiry and read real subscription quota on 2026-11-14. It returned 64% used in a 300-minute window and 28% in a 10080-minute window, without a model call or Codex installation. Its optimized executable measured 217,456 bytes. Credentials were discarded on exit; this is not the measured size of the entire product addition.

The candidate now uses the same native flow with QuotAI-owned Keychain credentials, serialized token refresh and the direct usage endpoint. It does not import the user's existing Codex credentials. The API/authentication boundary remains an unofficial integration based on public upstream implementation, not a separately supported quota API. See [the source investigation](../quotai/research/openai-quota-sources-2026-11-14.md) and [detailed behavior contract](../../docs/codex-quota.md).

## QuotAI integration boundaries

Repository inspection on 2026-11-14:

- [`QuotaMeter`](../../QuotAICore/Sources/MenuPresentation.swift) can hold usage and reset data with missing period dates, but the presenter currently takes explicit Cursor/Other/Grok arguments. Adding an OpenAI name alone would not wire a provider into the app.
- [`QuotaStore`](../../QuotAI/QuotaStore.swift) owns explicit Cursor/Grok state, credentials, refresh scopes, error state and timers. A Codex failure needs its own state so it cannot replace Cursor's menu-bar authentication state or block a successful Cursor/Grok refresh.
- [`RefreshPlanner`](../../QuotAICore/Sources/RefreshPlanner.swift) has exactly two request families. Codex buckets/windows would share one provider read while retaining individual reset times. Reuse quiet-hours and retry policy deliberately; do not bypass the scheduling gates with an extra independent polling loop.
- [`PaceHistorySampleStore`](../../QuotAICore/Sources/PaceHistorySampleStore.swift) stores a closed meter-ID enum and requires period start plus elapsed percentage. Do not put Codex samples into an existing meter ID or treat a rolling window as a verified billing cycle. Pace and history are confirmed out of scope for the first version; pace-based corridor alerts also require a separately verified period model before future adoption.
- [`KeychainStore`](../../QuotAI/KeychainStore.swift) currently stores one Cursor credential object. Reusing that account key for OpenAI credentials would overwrite Cursor authentication. If Codex manages credentials, let it own that lifecycle rather than adding token copies to QuotAI's Cursor store.

Keep the implementation concrete: a Codex read adapter, a parsed snapshot with bucket/window identity, provider-local status, a panel section and an optional menu-bar display. There is no demonstrated need yet for a general plugin/provider framework.

## Verification and next action

Acceptance checks now live with [the detailed Codex contract](../../docs/codex-quota.md), so the implementation evidence has one current home. The feature remains open until that acceptance is complete.

The initial full `make test` passed, including new parsing and per-window refresh-policy tests. The native probe's offline and loopback checks passed. The candidate builds and its code signature verifies. Running-app checks have observed a connected account, both quota windows, a manual Codex refresh and editable threshold controls; further evidence is recorded in the detailed contract as it is verified.

The feature is an uncommitted candidate on `feat/codex-allowance`, not a release. Its version is `0.21.0-rc.1` (build 67); public README claims remain on 0.20.0. Complete running-app acceptance and final tests before proposing release.
