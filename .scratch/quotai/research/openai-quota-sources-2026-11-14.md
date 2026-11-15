# OpenAI quota sources

Implementation update, 2026-11-14: the user selected direct native Swift integration. A subsequent in-memory probe completed browser OAuth, validated the ID-token signature/identity and read real 300-minute / 10080-minute windows without a Codex helper or model call. Its optimized executable is 217,456 bytes. Earlier unverified/live-access statements below describe the evidence available at those research stages. Current candidate behavior and outstanding checks are recorded in [the Codex contract](../../../docs/codex-quota.md).

Date: 2026-11-14. Status: discovery complete; live quota access and product implementation unverified. Supports [issue #54](https://github.com/marotron/QuotAI/issues/54), not an adopted behavior contract.

## Recommendation

Start with an optional **Codex subscription quota** meter using the documented local Codex app-server account interface. Show only returned quota buckets, usage percentages and reset times. Keep API spending and unrelated ChatGPT limits outside the first slice. This is a proposed scope, not a claim that every account exposes the same windows.

The next step is a bounded live-access spike with an explicitly connected account, isolated authentication storage, and no inference requests. Source inspection establishes feasibility, not a working integration.

## Evidence checked

- Read current official OpenAI documentation and first-party Codex source. GitHub HEAD was `81b995a6c9a4c978f399775cfa5ce50702368749`; exact files at that revision were downloaded and inspected, rather than treating moving `main` as the installed client.
- The installed IDE-bundled `codex` reports `codex-cli 0.169.0-alpha.11.1`. `codex app-server --help` exposes stdio and protocol generation. Stable TypeScript bindings were generated without `--experimental` to `/private/tmp/quotai-openai-protocol-2026-11-14` by the parent investigation and independently to `/private/tmp/quotai-openai-protocol-research`.
- No local credential files or Keychain secrets were read. No login, authenticated usage request, model request, reset redemption, or logout was performed. Temporary bindings are inspection artifacts, not repository dependencies.

## Sources and coverage

| Surface | Evidence | Implication |
|---|---|---|
| Codex/eligible shared subscription allowance | Documented `account/rateLimits/read` and `account/rateLimits/updated`; single and multiple bucket representations. [App-server docs](https://learn.chatgpt.com/docs/app-server#auth-endpoints) | Best first integration candidate; not a universal OpenAI balance. |
| Broader ChatGPT features | Uploads, images and voice have separate limits. [Codex plan guide](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan) | Do not label Codex data as all ChatGPT quotas. No complete consumer quota API was established in this investigation. |
| API usage | Organization usage endpoint offers bucketed token/request counts, model/project/key filtering and grouping; examples require an Admin API key. [Usage reference](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage/methods/completions) | Separate authentication and accounting feature. Counts do not provide subscription allowance remaining. |
| API costs | `/v1/organization/costs` returns monetary amounts with currency, daily buckets and pagination; example uses an Admin API key. [Costs reference](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage/methods/costs) | Appropriate for a future spending meter, not a Codex quota adapter. |
| API request limits | Response headers expose remaining requests/tokens and reset intervals. [Rate-limit guide](https://developers.openai.com/api/docs/guides/rate-limits#rate-limits-in-headers) | Throughput limits differ from subscription allowance and billing. Do not issue paid model requests merely to obtain headers. |

Current plan guidance describes shared allowances where applicable; a banked full reset can change the weekly reset date. Thus server observations must take precedence over a locally assumed calendar. [Codex plan guide](https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan)

## Documented interface and local schema

The documented read returns `rateLimits` for compatibility and optional `rateLimitsByLimitId` for multiple buckets. Window data includes `usedPercent`, nullable `windowDurationMins`, and nullable `resetsAt` (Unix seconds). Bucket names and duration come from the response; primary and secondary must not be hardcoded as five-hour and weekly. The same documentation describes optional credit/reset-credit data. [App-server docs](https://learn.chatgpt.com/docs/app-server#6-rate-limits-chatgpt)

The inspected source and installed stable bindings agree on these consequential boundaries:

- `RateLimitSnapshot` carries optional identity/name/model-alias metadata, windows, credits, spend-control and limit-reached state.
- `CreditsSnapshot` uses `hasCredits`, `unlimited`, and nullable string `balance`; balance is not an established USD amount.
- Nullable `ordinaryUsageAllowed` is backend permission. A percentage falling or a clock passing reset does not prove recovery.
- `accountId` can bind a snapshot to its account.
- Rolling updates are sparse: merge available values into the previous full snapshot or refetch; absent account metadata does not erase prior metadata.

[Pinned account protocol](https://github.com/openai/codex/blob/81b995a6c9a4c978f399775cfa5ce50702368749/codex-rs/app-server-protocol/src/protocol/v2/account.rs)

Local generation confirms a protocol surface exists in this alpha binary. It does not establish a stable minimum supported Codex version, a real account payload, account eligibility, or parity with current public HEAD. Pin and test an actual supported binary before shipping.

## Authentication and supported boundaries

App-server documents managed ChatGPT browser/device login and automatic token management. It explicitly allows continued app-server authentication for local/open-source applications while recommending Sign in with ChatGPT; it excludes commercial/hosted services. QuotAI's local open-source distribution makes the managed local path a candidate, not a general hosted OAuth integration. [App-server auth documentation](https://learn.chatgpt.com/docs/app-server#auth-endpoints)

The new [Sign in with ChatGPT app-server guide](https://developers.openai.com/siwc/token-sharing-open-source/codex-app-server) configures a Responses provider using the application's own OAuth access token and `requires_openai_auth=false`. It documents inference, not an interchangeable account-quota read. Do not assume those tokens authorize the existing quota interface. The [registration guide](https://developers.openai.com/siwc/token-sharing-open-source/sign-in) establishes a distinct dynamic-client flow; scope compatibility still needs evidence.

The public account source marks external `chatgptAuthTokens` unstable and internal-only. Despite broader wording in the app-server guide, avoid this mode for QuotAI. [Pinned account source](https://github.com/openai/codex/blob/81b995a6c9a4c978f399775cfa5ce50702368749/codex-rs/app-server-protocol/src/protocol/v2/account.rs)

Codex caches credentials in a file or OS credential store; CLI/IDE share their cached login and signing out affects both. Explicit `keyring` storage fails if unavailable, whereas `auto` can fall back to a file. [Authentication guide](https://learn.chatgpt.com/docs/auth#login-caching)

**Proposed integration rule:** use an isolated Codex home and an explicit Keychain-backed store for the spike. Verify Keychain namespace isolation, refresh ownership, workspace selection and logout behavior before adopting it. Never point a second token-refreshing owner at the live IDE cache by default. QuotAI should receive quota snapshots from the helper rather than copy bearer/refresh tokens into its own parser or logs. If isolation cannot meet the application's secret-storage contract, revisit the design before production wiring.

The backend source calls internal `/wham/usage` or `/api/codex/usage` routes. Those are implementation evidence, not a public HTTP integration contract. Prefer the documented app-server method to reproducing those requests. [Pinned backend implementation](https://github.com/openai/codex/blob/81b995a6c9a4c978f399775cfa5ce50702368749/codex-rs/backend-client/src/client/rate_limit_resets.rs)

## Proposed first slice and remaining checks

1. Probe one pinned Codex helper version with managed sign-in in isolated storage; read quota without starting a thread or turn. Capture a redacted fixture and compare returned windows/reset times with the provider's usage UI.
2. Support all returned bucket IDs and optional windows. Distinguish zero usage, missing window, unavailable reset, exhausted included allowance and credits. Never convert absent data to zero or “unlimited.”
3. Start with raw used/remaining percentages, reset countdown, account identity and freshness/error state. Preserve previous readings on transient errors; account changes must never display the previous account's reading as current.
4. Add bounded polling using existing quiet-hours/manual-refresh/error-delay conventions; verify provider throttling and helper lifetime. A notification is not proof that another process pushes remote usage into this helper continuously.
5. Defer pace/corridor alerts and existing elapsed-based history until period semantics are verified. The schema has no explicit period start; `reset − duration` is only an inferred boundary. Account resets and optional windows require a separate decision. Timestamped quota observations could be useful later without pretending they establish an authoritative billing period.

Unverified: real payload and permissions across plan types; whether model aliases are present for this account; minimum helper version and distribution/update strategy; sandbox/process permissions; Keychain ownership and isolation; rate-limit/backoff behavior; reset rollover and credit semantics. These checks are implementation prerequisites, not evidence that discovery failed.

## Self-contained macOS setup feasibility

Continuation date: 2026-11-14. The user has confirmed Codex subscription allowance, dropdown plus optional menu-bar display, and operation without a separate Codex installation. **The evidence warrants a bounded packaging/authentication prototype. No source-level packaging blocker was established; production feasibility remains conditional on the live checks below.** This finding does not select product update or sign-in policy.

### Confirmed release and redistribution facts

The current stable release is [`rust-v0.169.0`](https://github.com/openai/codex/releases/tag/rust-v0.169.0), published 2026-11-13; its annotated tag resolves to source commit `d32063f96c2dff1dc96af839b3952abb6acfeda4`. This is distinct from the earlier inspected public HEAD and installed alpha. Release metadata supplies separate `codex-app-server-aarch64-apple-darwin.tar.gz` and `codex-app-server-x86_64-apple-darwin.tar.gz`, 87,595,276 and 94,930,320 bytes compressed, with SHA-256 digests. Fuller `codex-app-server-package-*` archives are also published for both architectures.

The arm64 standalone archive was downloaded into `/private/tmp/quotai-codex-packaging-research`, verified against release digest `86270c0473858bc5a43f139fc1c105b90b4850c4b779103aced907d1ab19e1e4`, and inspected without executing it. It contains one 218,116,928-byte native executable. `vtool -show-build` reports `minos 11.0`, SDK 15.5; `otool -L` lists only system libraries and Apple frameworks. This establishes no linked Node/npm/Homebrew runtime requirement for this artifact. It does not prove every runtime path works on macOS 14, nor establish the Intel binary's minimum OS. The canonical package also includes code-mode/execution helpers and `rg`; source alone does not establish that those can be omitted for every account-only startup. [Published artifact](https://github.com/openai/codex/releases/download/rust-v0.169.0/codex-app-server-aarch64-apple-darwin.tar.gz), [pinned package layout](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/scripts/codex_package/README.md)

Codex's repository license is Apache-2.0. Its redistribution section requires recipients receive the license, modified files carry change notices, applicable source notices be retained, and applicable NOTICE attributions remain readable. The root NOTICE identifies OpenAI and Ratatui/MIT attribution. These are factual contents of the checked files; they do not establish that the root NOTICE exhausts licenses of every statically linked dependency or optional bundled resource. A shipped inventory must preserve applicable third-party notices for the exact chosen binary/package. [Pinned LICENSE](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/LICENSE), [NOTICE](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/NOTICE), [license documentation](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/docs/license.md)

### Confirmed authentication isolation mechanisms

At the stable release's direct keyring backend, the service is `Codex Auth`; the account key is `cli|` plus the first 16 hexadecimal characters of SHA-256 of the canonical Codex-home path. Saving/deleting uses that key; deletion removes that home's fallback auth file, not an arbitrary other home's file. Explicit `Keyring` chooses keyring storage directly; `Auto` is a different implementation that can fall back to file storage. [Pinned credential store](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/auth/storage.rs)

There are two keyring-backed implementations. `secret_auth_storage` selects an encrypted local secrets file with a Keychain-backed secret; its default is enabled on Windows, disabled on macOS. Therefore “keyring” alone should not be assumed to mean tokens always reside directly in Keychain across versions/configurations. A prototype intended to preserve QuotAI's current Keychain-only credential boundary should explicitly use direct storage: `cli_auth_credentials_store="keyring"` and `features.secret_auth_storage=false`, subject to managed requirements. An unavailable Keychain should surface an error, with no plaintext fallback. [Backend selection](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/core/src/config/auth_keyring.rs), [feature default](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/features/src/lib.rs)

**Proposed isolation:** create a permanent real directory under QuotAI Application Support before launch, set `CODEX_HOME` only in the helper's environment, and keep its canonical path stable across app updates. Do not symlink it to the user's `.codex`. Home-derived keys substantiate namespace separation, but Keychain access prompts, rotation, logout/revocation and coexistence still require live verification. Isolation does not grant permission to override organization-managed auth restrictions.

### Proposed packaging and launch experiment

Bundle a pinned, verified helper/package in QuotAI rather than resolving an IDE extension path or asking users to install a CLI. Start it by absolute bundle path with stdio pipes and an app-owned working directory/environment. The standalone binary directly supports `--listen stdio://`; it is not invoked as `codex-app-server app-server`. Perform the protocol handshake, then account/sign-in/quota methods only. Bound startup/read timeouts, drain stderr without persisting secrets, stop on disable/quit, and verify termination before replacing the helper. [Stable entry point](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/app-server/src/main.rs)

QuotAI currently targets macOS 14, has App Sandbox disabled, and defaults its DMG build to arm64. Its signing script handles the app and QuotAICore, with no embedded-helper signing step. An embedding experiment therefore needs explicit helper/resource staging and nested-signature verification; production Gatekeeper/Keychain behavior must be checked from the final DMG. Existing release signing is evidence of work required, not evidence that app-server embedding fails. [Project settings](../../../project.yml), [DMG signing script](../../../Scripts/release/dmg.sh)

A simple candidate update strategy is to ship a reviewed helper pin with each QuotAI release, retaining it unchanged between app updates. This removes a runtime installer/version-drift dependency; it increases package size and makes QuotAI responsible for promptly shipping helper fixes. Independent helper downloads/updates are a separate product choice, not required by the source evidence.

### Prototype exit checks

- Launch the exact packaged build on a clean macOS 14+ Mac without Codex, Node, Homebrew or adjacent IDE resources; establish whether the standalone artifact suffices or the canonical package is required. Verify Intel separately if included in QuotAI's release target.
- Verify the final signing/Gatekeeper path and direct Keychain mode; demonstrate that neither successful sign-in nor failed Keychain access writes plaintext auth.
- Sign in, read a real quota snapshot without inference, relaunch and refresh; sign out and confirm an existing independent Codex installation/account remains intact.
- Confirm helper startup background work, resource usage, shutdown, protocol compatibility and error behavior are suitable for quota polling. Read-only quota intent does not imply the general-purpose helper has no startup side effects.
- Retain license/NOTICE and complete an exact dependency/resource attribution inventory before distribution. No helper was installed, executed or used to authenticate during this feasibility continuation.

## Direct integration alternative

Continuation date: 2026-11-14. **The 218 MB helper is not technically required for an HTTP quota read.** It is Codex's general-purpose app-server, including conversation, tool/execution, configuration and authentication infrastructure. Its benefit here is a documented local interface and managed login/refresh implementation, not quota-computation machinery that must run on the Mac. The previous packaging feasibility finding established one possible route, not a necessity or selected design. [App-server dependencies](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/app-server/Cargo.toml)

### What the quota read actually does

At stable source revision `d32063f96c2dff1dc96af839b3952abb6acfeda4`, the backend performs an authenticated **GET** to `/wham/usage` under its ChatGPT backend base, or `/api/codex/usage` under its alternate base. For normal `https://chatgpt.com` routing, the client normalizes the base to `/backend-api`, producing `https://chatgpt.com/backend-api/wham/usage`. The read has no model prompt or request body. The passive reader does not opt into the optional Luna Reserve header. [Quota request](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/backend-client/src/client/rate_limit_resets.rs), [base routing and headers](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/backend-client/src/client.rs)

The inspected ordinary bearer path attaches `Authorization: Bearer <access token>` and, when available, `chatgpt-account-id` from the selected account/workspace identity; the backend client sets a User-Agent. Account selection cannot be replaced with an email address or guessed from whichever browser is open. Government/enterprise routing and transport policies can add requirements; this source inspection does not establish that those ordinary headers are sufficient for every account. [Bearer header implementation](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/model-provider/src/bearer_auth_provider.rs), [account-bound authentication](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/model-provider/src/auth.rs)

**Inference:** native Swift `URLSession` plus JSON decoding can perform that read without bundling an agent runtime. The unresolved part is a suitable, maintainable sign-in grant and private HTTP contract—not networking capability or a separate Codex installation.

### Authentication choices are distinct

| Candidate | Verified evidence | Remaining boundary |
|---|---|---|
| QuotAI's own Sign in with ChatGPT registration | Official own-app flow documents browser authorization, PKCE, state/nonce, validated ID token and issued client ID; no client secret. [Registration guide](https://developers.openai.com/siwc/token-sharing-open-source/sign-in) | Documents identity and eligible plan inference, not permission to read `/wham/usage`. Do not assume the token audience/scopes or workspace identity fit that endpoint. |
| Reimplement Codex's native managed login | Source uses `/oauth/authorize`, PKCE and loopback callback, then `/oauth/token`; refresh retains issuer/client provenance. [Browser login](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/server.rs), [token grants](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/oauth/client.rs) | Public source/client identifiers do not establish permission for a separate product to impersonate Codex or obtain equivalent grants. This route needs explicit contract/support clarification. |
| Bundle the helper's managed login | Existing documented local app-server auth path, subject to the earlier stated availability boundaries. | Larger binary, process/signing/update ownership and still-unverified account access. It avoids duplicating much of the auth lifecycle, not all integration risk. |

For own-app OAuth, official refresh guidance uses the issued client ID and rotating refresh token, requires serialized refreshes, and keeps tokens in protected storage. A direct QuotAI design should own separate Keychain records, preserve registration/account identity, replace token generations atomically, and handle revoked/expired grants without retries that race another owner. Existing Codex-cache import would not meet the clean setup target on its own and introduces ownership risk. [Accounts and sessions](https://developers.openai.com/siwc/token-sharing-open-source/profiles-and-sessions#refreshing-tokens)

### Fair implementation comparison and next evidence

Direct native integration avoids the measured 218 MB helper, its child-process lifecycle and helper release updates. It adds responsibility for browser callback/security, Keychain and token rotation, account binding, private payload changes, routing, errors and throttling. The helper is an easier documented integration boundary, but it is still broad software to package and maintain for a narrow read. Neither path has live verification in QuotAI.

The private HTTP endpoint has **implementation evidence**, not a public supported quota-API contract. The documented app-server read must not be used as evidence that the underlying route is independently supported. A direct approach deserves a bounded feasibility investigation before selecting helper packaging, with these checks:

1. Establish which own-app authentication grant, if any, is supported for subscription-quota reads; verify account/workspace identity access. Do not treat an inference scope as a quota scope or silently reuse Codex's client identity.
2. With a separately authorized test connection, read quota and compare a sanitized payload with the provider UI; no inference or reset redemption is needed. Check redirect/challenge/error behavior with native networking.
3. Demonstrate refresh rotation, relaunch, sign-out and expiry using QuotAI-owned Keychain credentials, without touching an independent Codex login.
4. Decide explicitly whether the private-endpoint maintenance boundary is acceptable if no public quota-read contract exists. Preserve unavailable/stale state and a clear recovery path when it changes.

Only first-party public source/docs were inspected for this continuation. No credentials, authenticated calls, prototype code or installations were used. Packaging remains undecided.

### Native authentication spike details

Continuation 2026-11-14: the user authorized proceeding with direct Swift integration. The following is a concrete upstream-compatible experiment, not a claim of a public quota API. All source details below are pinned to stable commit `d32063f96c2dff1dc96af839b3952abb6acfeda4`.

- **Public client identity:** upstream constant `app_EMoamEEZ73f0CkXaXp7hrann`. It is not a client secret. An application should identify itself truthfully rather than label itself the official Codex client. [Auth manager](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/auth/manager.rs)
- **Browser authorization:** `https://auth.openai.com/oauth/authorize`; `response_type=code`; client ID above; exact loopback `redirect_uri`; scopes `openid profile email offline_access api.connectors.read api.connectors.invoke`; PKCE challenge using S256; cryptographically random `state`. Upstream adds `id_token_add_organizations=true`, `codex_cli_simplified_flow=true` and an originator. Its callback is `http://127.0.0.1:<port>/auth/callback`, default port 1455. Validate state before accepting either code or OAuth error. [Login server](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/server.rs), [authorization builder](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/oauth/authorization.rs)
- **Code exchange:** form POST to `https://auth.openai.com/oauth/token` with `grant_type=authorization_code`, `client_id`, `code`, the identical `redirect_uri`, and `code_verifier`; no client secret. Code response expects `access_token`, `id_token`, `refresh_token`. Never automatically replay a code exchange after an ambiguous timeout. [Exchange implementation](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/server.rs)
- **Refresh:** the same token endpoint, upstream JSON encoding with `grant_type=refresh_token`, owning `client_id`, and `refresh_token`. Optional diagnostic `refresh_reason` values are `proactive_expiry`, `scheduled`, `unauthorized_recovery`, `forced`; no resource is sent by this Codex path. Refresh response token fields are optional; retain the previous value when absent. Serialize the operation and commit replacement credentials together to the app's own Keychain record. Permanent expired/reused/revoked/invalid-grant results require a new login. [Token grant construction](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/oauth/client.rs), [refresh response and persistence](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/auth/manager.rs)
- **Identity for quota:** inspect the returned ID token's `https://api.openai.com/auth` object's `chatgpt_account_id`; this is distinct from email and user identity. Treat decoding as routing metadata, not proof that an unvalidated claim authorizes an account. The quota service receives the bearer token with its account scope and determines access. [Token metadata](https://github.com/openai/codex/blob/d32063f96c2dff1dc96af839b3952abb6acfeda4/codex-rs/login/src/token_data.rs)

The official local/open-source app-server guidance supports continuing those existing integrations and excludes commercial/hosted use of app-server authentication. It recommends the newer Sign in with ChatGPT flow. It does **not** explicitly prohibit this local native experiment; nor does it explicitly document independent reuse of Codex's client registration for quota reads. These are different observations. No additional legal-approval gate is inferred here. Actual authorization/redirect acceptance and quota scope remain things the isolated experiment must establish. [Current auth guidance](https://learn.chatgpt.com/docs/app-server#auth-endpoints)

**Browser-session alternative:** no primary evidence found here establishes that a plain ChatGPT cookie session captured in `WKWebView` is interchangeable with the bearer flow above. That would be a separate private web-session integration with cookie expiry and embedded-login compatibility to verify. For the first spike, opening the system browser with OAuth and receiving a loopback callback follows the inspected native client more closely. A web view can display a login site, but that alone does not demonstrate access to quota data or a refresh-token grant.

CodexBar's current own documentation describes reading existing Codex tokens while delegating native token refresh to the owning CLI; it is primary evidence for its read-only ownership policy, not a standalone-login design satisfying QuotAI's no-install requirement. [CodexBar OAuth resolver](https://github.com/steipete/CodexBar/blob/main/docs/codex-oauth.md)
