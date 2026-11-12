# Perplexity quota (optional provider)

Type: task
Status: open
Blocked by:
Target: next version (MINOR at ship)
GitHub: https://github.com/marotron/QuotAI/issues/48
Spec: [.scratch/perplexity-quota/spec.md](../../perplexity-quota/spec.md)

## Question

Add Perplexity as an optional third provider next to Cursor and Grok Bot. Off by default. When on, a dropdown row shows the raw quota. QuotAI learns the reset schedule from observed readings because the endpoint has no reset time (as far as we know).

## Open questions

1. Payload shape: is there a limit or reset field, or only a remaining count? Pending example JSON.
2. Which `perplexity.ai` cookie is the session credential?
3. Does Google sign-in block the embedded web view? If so, the paste fallback is the only path for Google accounts.
4. Does Perplexity throttle the 1-per-minute narrow phase?
5. Is logging a jump to a new maximum as "unexpected level" (not a reset) acceptable?

## Context

Decisions and the TDD seam plan live in the spec. Implementation waits for the example payload and approval of the HTML proto for the dropdown row and Settings controls.

## Comments

### 2026-11-12

Ticket created during housekeeping to mirror GitHub [#48](https://github.com/marotron/QuotAI/issues/48). Spec status there: draft, not approved for implementation.
