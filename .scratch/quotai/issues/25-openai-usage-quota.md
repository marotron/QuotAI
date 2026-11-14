# OpenAI usage and quota tracker

Type: task
Status: open
Blocked by:
GitHub: https://github.com/marotron/QuotAI/issues/54

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
