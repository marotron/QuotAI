# Official Cursor API migration path

Type: grilling
Status: open
Blocked by:
Target: parked (roadmap / fog)
GitHub: https://github.com/marotron/QuotAI/issues/11

## Question

When Cursor ships an official Spending or quota API, how does QuotAI migrate off the unofficial Connect and `state.vscdb` path?

Today's source of truth is the Cursor Spending UI and Connect (`GetCurrentPeriodUsage`, `GetSandUsageStatus`) with the IDE Bearer token. The unofficial fetch is acceptable but flaky until an official API exists.

## Open questions

- [ ] Auth model: OAuth or tokens?
- [ ] Meter parity: Cursor Models, Other, and Grok.
- [ ] Feature flag or dual path during the transition?
- [ ] Deprecation of the `vscdb` import.

## Context

Source: wayfinder map (not yet specified) and `docs/pr.md` non-goals.

## Comments

### 2026-11-12

Ticket created during housekeeping to mirror GitHub [#11](https://github.com/marotron/QuotAI/issues/11).
