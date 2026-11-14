# Refresh more often when quota usage is high

Type: task
Status: open
Blocked by:
GitHub: https://github.com/marotron/QuotAI/issues/55

## Proposal

Let users configure faster automatic quota refresh when a usage threshold is reached, for the remainder of that quota period. For example, at 90% weekly usage or 50%, 70%, or 80% usage in a five-hour window, switch to a chosen interval such as one minute until reset. These numbers are examples, not agreed defaults.

In Settings, users should be able to choose thresholds by quota period (such as five-hour, daily, or weekly) and the faster refresh interval, with appropriate support for different providers, models, and quota packages where the underlying data permits it.

## Acceptance sketch

- [ ] Configure a usage threshold and faster interval for relevant quota periods in Settings.
- [ ] When a quota reaches its configured threshold, refresh the affected quota source more frequently through that period's reset.
- [ ] After reset, return to the applicable normal cadence unless another active rule calls for faster refresh.
- [ ] Support simultaneous quota windows and explain how their rules affect shared fetches.
- [ ] Handle missing or stale quota/reset data and provider rate limits without misleading users or causing uncontrolled retries.
- [ ] Preserve the user's existing refresh preferences and document interactions with fixed and Dynamic refresh.

## Open questions

- Are rules configured per provider, model, package, period, or a combination? Which periods and quotas can current and future providers actually expose?
- Are multiple thresholds and intervals per period needed, or one rule per period? What defaults and minimum interval are appropriate?
- Should a rule remain active until reset if a later reading drops below its threshold, and what happens if the reset time is unknown or changes?
- How should overlapping rules, shared provider requests, Dynamic refresh, manual refresh, errors, and rate limiting interact?
- How should this interact with proposed quiet hours, including whether quiet hours suppress the faster automatic cadence?

## Related work

- [#12](https://github.com/marotron/QuotAI/issues/12): closed polling/refresh UX work; Dynamic refresh already changes cadence as reset approaches. Per-family Dynamic refresh shipped in [#32](https://github.com/marotron/QuotAI/pull/32). This proposal adds a usage-based trigger.
- [#31](https://github.com/marotron/QuotAI/issues/31): proposed quiet hours for automatic polling.
- [#48](https://github.com/marotron/QuotAI/issues/48): Perplexity proposal includes provider-specific polling around a predicted reset.
- [#54](https://github.com/marotron/QuotAI/issues/54): OpenAI quota proposal needs investigation of available model-specific and multiple-window quota data.

## Comments

### 2026-11-14

Feature proposal captured from user discussion and mirrored to GitHub [#55](https://github.com/marotron/QuotAI/issues/55). Thresholds, cadence, and settings design remain to be decided.

### 2026-11-14 — candidate implementation

Candidate work for 0.20.0 is in progress. Decisions, scope and outstanding verification are recorded in [the automatic refresh contract](../../../docs/automatic-refresh.md). The issue remains open until acceptance is verified.
