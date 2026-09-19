# Burn-rate formula

Type: grilling
Status: resolved
Blocked by: 01

## Question

Lock the daily sample model and the menu wording for pace:

- Sample once per day (store `% used` + timestamp + period end)?
- How to compute on-pace vs over-pace (e.g. 50% used with ~half the period left ≈ "100% rate")?
- Days-to-exhaustion estimate and when to warn of early depletion
- Exact short strings shown in the menu for each state

Why it matters: the PoC and product spec need one agreed formula, not competing heuristics.

## Answer

Locked 2026-09-19 with user acceptance of sample model (2) and explicit “finish planning” for the remaining formula defaults.

**Sampling:** Refresh live `%` / days-left on every successful fetch. Commit **one pace sample per meter per local calendar day** (first successful fetch that day wins): `{percentUsed, sampledAt, periodEnd}`. No multi-day time-series required in v1 beyond “today’s sample” (+ optional yesterday only if needed later). Polling cadence stays in fog.

**Baseline:** Even burn = linear from 0% at period start to 100% at period end. Fraction elapsed `t = clamp((now - periodStart) / (periodEnd - periodStart), ε, 1)` with small `ε` (e.g. 1 hour / period) so day-0 does not explode. **Pace ratio** `r = percentUsed / (100 * t)` — so `r = 1` is exactly on pace (menu “100% pace”).

**Dial / colors (from meters ticket):** Dial maps `r` on log scale: min→0, 12 o’clock→1 (100% even), max→∞. **Green band:** `0.90 ≤ r ≤ 1.10`. **Blue (under):** `r < 0.90`. **Red (over):** `r > 1.10`. Bar “worse meter” = higher `r` (more over-pace); if one meter missing, use the other.

**Days-to-exhaustion:** Instantaneous daily burn `b = percentUsed / max(daysElapsed, ε_days)`. Remaining days at that burn `d_ex = (100 - percentUsed) / b` when `b > 0` and `percentUsed < 100`; else `∞` / “—” . **Early depletion (menu only, no notification in v1):** if `d_ex` is finite and `now + d_ex < periodEnd`, treat as early; show exhaustion hint in the pace string.

**Menu strings (per meter):**

| State | Short string |
|-------|----------------|
| Under | `Under · {r as %} pace` |
| On | `On pace · {r as %} pace` |
| Over | `Over · {r as %} pace` |
| Early | append ` · ~{N}d left` when early depletion |
| No period bounds | `Pace n/a` |
| Exhausted (`percentUsed ≥ 100`) | `Exhausted` |

`{r as %}` = `round(r * 100)` with a `%` suffix (e.g. `100% pace`). Dropdown shows these next to each meter’s dial; bar Pace mode uses the worse meter’s color + optional compact `↑`/`=`/`↓` or dial only (UI polish later).

## Comments

### Progress (grilling)

- **Sample model:** (2) live fetch for meters; one pace sample per meter per local day. User: ok.
- **Rest of formula:** accepted as planning defaults under “finish this planning and progress to build”.
