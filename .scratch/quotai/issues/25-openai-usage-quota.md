# OpenAI usage and quota tracker

Type: task
Status: open
Blocked by:
GitHub: https://github.com/marotron/QuotAI/issues/54
Research: [OpenAI quota sources, 2026-11-14](../research/openai-quota-sources-2026-11-14.md)
Draft implementation brief: [Codex quota first slice](../../openai-quota/spec.md)

## Proposal

Add an OpenAI usage and quota tracker alongside the existing Cursor and Grok Bot meters. Research how to obtain current usage and quota information before deciding the implementation and presentation.

## Open questions

- Which OpenAI products and account types expose useful quota information, and which should be in scope (ChatGPT/Codex subscriptions versus API usage and spending)?
- What data sources, authentication requirements, access limitations, and supported or unofficial interfaces are available?
- Which usage, limits, reset times, billing periods, and model-specific or multiple-window quotas can be retrieved?
- How should credentials be acquired and stored securely, data refreshed, and expired authentication or unavailable data handled?
- Which existing pace, history, alerts, and menu-bar features fit the available data?

Show available usage and reset information consistently with the existing meters, and indicate unavailable or stale data without disrupting other meters. Related: [Perplexity quota](20-perplexity-quota.md).

## Comments

### 2026-11-14

Feature proposal created as GitHub [#54](https://github.com/marotron/QuotAI/issues/54). Data source and scope require investigation.

### 2026-11-14 — source discovery

Discovery authorized after backlog review. The documented Codex app-server `account/rateLimits/read` method is the leading source for subscription quota windows. Local `codex-cli 0.169.0-alpha.11.1` exposes the method and nullable usage-window fields in generated non-experimental TypeScript bindings. This verifies protocol availability, not live account access. No local credentials were inspected and no authenticated provider calls were made.

Proposed first slice: explicitly labelled Codex subscription quota windows, with provider-local freshness/authentication state. General ChatGPT limits and API organization usage/spending remain separate source investigations; existing billing-cycle pace/history should not be applied to rolling quota windows without verification.

Next is a bounded authentication and sanitized real-response spike. App-server managed authentication is documented for local/open-source applications; OpenAI recommends migration to Sign in with ChatGPT, but quota-read access through that newer integration has not been established. Credential isolation, executable distribution and actual returned fields remain unresolved. See the linked research and draft brief for evidence and acceptance checks. No implementation decision is locked and the feature remains open.

Related-work check: searched GitHub issues in all states for OpenAI, Codex, provider and Perplexity; found existing #54, #48, #55 and #37. Continued this ticket; no duplicate created. GitHub issue content was read but not changed.

### 2026-11-14 — scope confirmed in planning

User selected **Codex allowance** as the OpenAI integration's scope. API spending is outside this effort. Remaining product and authentication choices are being discussed; the draft is not approved as a whole and no implementation is verified.

User selected **dropdown and optional menu-bar display** for the first version. Exact window selection, visual treatment and setup requirements remain open. This supersedes the earlier dropdown-only proposal in the discovery brief.

User selected **works without a separate Codex installation** as the setup target. Packaged-helper feasibility and credential isolation need verification; an installed CLI requirement is not accepted by this decision.

User selected **separate menu-bar indicators for each quota window**, with all available windows shown in the dropdown. Exact visual treatment remains open; the earlier single-window alternatives were not selected.

User selected **quota and reset times first**, with pace and history deferred to later work. Refresh-policy and notification scope remain undecided.

User selected **configurable high-usage refresh rules** for Codex windows, subject to quiet hours and retry limits. Exact rule controls/shared-fetch semantics need definition and verification. Notification scope remains undecided.

User selected **display quota status only**, with quota notifications deferred. The brief now consolidates the confirmed choices; UI details, helper delivery and live authentication remain open. Static packaging research supports a bounded prototype but does not verify runtime behavior.

User wants a **smaller solution than the 88 MB download / 218 MB full app-server**. Direct native quota fetching is the next approach to investigate. The HTTP operation does not technically require app-server, but an appropriate authentication grant and internal-endpoint compatibility remain unverified. No helper-delivery choice or authentication route has been approved.

### 2026-11-14 — direct Swift implementation

User selected **Direct Swift integration**. A 217,456-byte native feasibility probe completed browser OAuth, verified the ID-token signature/identity and read 64% used in a 300-minute window plus 28% in a 10080-minute window. No model request, helper, existing credential import or credential persistence was used in the probe.

Candidate **0.21.0-rc.1, build 67**, on `feat/codex-allowance` now adds native sign-in and separate Keychain credentials, all returned quota windows, optional per-window menu-bar rings and configurable high-usage refresh rules using the existing timer. Pace/history/notifications are deferred as agreed. Initial `make test`, probe checks, candidate build and signature verification passed. Running-app Account/Refresh checks have observed a connected account, two returned windows, manual refresh and editable rule controls. The [Codex quota contract](../../../docs/codex-quota.md) owns the remaining acceptance checks. This issue remains open; nothing has been committed, tagged or shipped.
