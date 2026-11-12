# Pace redesign: surplus/deficit vs ideal

Type: grilling
Status: open
Blocked by:
Target: fog / next redesign
GitHub: https://github.com/marotron/QuotAI/issues/47

## Question

Should QuotAI’s primary pace signal be **how far usage sits above or below ideal pace** (surplus/deficit), instead of the multiplicative rate `usage ÷ elapsed`?

If yes: hang alerts, panel/menu copy, and digestible visuals off that same spine.

## Context

- Locked today (`04-burn-rate-formula.md`, `PaceCalculator`): `r = percentUsed / (100 × t)` → “N% pace”.
- Corridors (`PaceAlertBands`) and pace history already live on the **used × elapsed** plane with an even-pace diagonal — a different mental model from the ratio headline.
- User direction (2026-11-09): starting point should be distance above/below ideal; that unlocks clearer alerts + visuals.

Draft working model on GitHub [#47](https://github.com/marotron/QuotAI/issues/47):

```text
deltaUsed = usedPct − (100 × t)
```

Related fog: GitHub [#13](https://github.com/marotron/QuotAI/issues/13) (pace dial) — may be reframed or superseded.

## Acceptance sketch (after grilling)

- [ ] Lock primary metric (absolute delta vs relative vs corridor headroom)
- [ ] Panel + menu-bar copy/visuals read from that signal
- [ ] Alerts keyed off the same signal (+ exhausted)
- [ ] QuotAICore tests + `docs/pace-chrome.md` / burn-rate notes updated together
- [ ] Explicit call on ratio UI and #13

## Open questions

- Exact primary metric and on-ideal dead zone
- Early-period ε behavior
- Menu-bar compact form
- Notify on surplus size, corridor cross, trend, or combination
- Keep `ratio` as secondary or remove
- How to explain the change to users who know “% pace”

## Comments

### 2026-11-09

User sketched the redesign verbally; mirrored to GitHub [#47](https://github.com/marotron/QuotAI/issues/47) as a fog/enhancement draft (not a locked formula).

### 2026-11-09 — concept brief

- Research: [../research/pace-surplus-best-practices.md](../research/pace-surplus-best-practices.md) (PMI SV/SPI, Google/Meta pacing, AWS Budgets)
- Interactive canvas: `pace-surplus-redesign.canvas.tsx` (geometry, equations, variants A–E, scenario switcher)
- HTML tweak proto: [../pace-fair-share-bars-prototype/index.html](../pace-fair-share-bars-prototype/index.html) (bars on elapsed-% axis + trajectory; layout A/B/C)
- Working proposal to grill: **display A (δ pp)** · **alerts D (corridors)** · **secondary E (forecast)** · **debug B (ratio)**
