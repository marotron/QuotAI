# Name the meters QuotAI surfaces

Type: grilling
Status: resolved
Blocked by:

## Question

Confirm what QuotAI v1 shows in the menu bar / menu:

1. Cursor Models (and related monthly pools): `% used` + days left until reset?
2. Grok Bot: `% used` + days left on its weekly cycle?
3. A burn-rate estimate derived from daily samples (on-pace / over-pace / days-to-exhaustion)?

Also decide whether **Other Models**, on-demand spend, or any other Spending rows are in or out of v1.

Why it matters: every later ticket (formula, PoC, spec, UI) hangs on which meters exist.

## Answer

**v1 meters:** Cursor Models and Grok Bot only. Each shows `% used` + days left. Pace is in: one pace signal per meter. Other Models, on-demand, and other Spending rows are out of v1 (open Spending page instead).

**Missing Grok:** show a Grok row as unavailable / error; Cursor Models still refresh.

**Menu bar (Settings):** default **Used + days left**, or **Pace** mode. Pace mode shows a **dial** driven by the **worse** of the two meters. Colors: green ≈ on pace, red = over, blue = under. Dial scale: min = 0, middle (12 o'clock) = 100% even burn (quota ÷ days), max → ∞; logarithmic min→middle and middle→max. Exact green ± band deferred to Burn-rate formula.

**Dropdown:** always full detail (`%`, days left, pace) plus a **small dial per meter**. Settings only change the bar glance, not the dropdown.
