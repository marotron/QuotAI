# Discrepancy marks on pace chart — decision prototype

**Status:** Winner locked — **Variant A (bands + strip)**.  
**Question answered:** Soft vertical grey bands for clustered periods + expandable strip under the chart.

**Open:** `open .scratch/quotai/discrepancy-marks-prototype/index.html` · `?variant=A|B|C` · ← / →  
(B/C remain for comparison only.)

## Visual source of truth

Panel chrome, copy, and legend match the **live v0.18.0** menu panel (screenshot 2026-11-07), not the older corridor-named pace-history prototype:

| Slot | Live naming |
| --- | --- |
| Meters | Cursor Models · Other Models · Grok Bot |
| Burn chips | Over burn · Under burn · Ideal pace |
| Visibility | Labels · Icons (grouped, no eye glyphs) |
| Axis titles | Used · Elapsed |
| End labels | Cursor · Other · Grok (+ icons) |
| Latest event | “Cursor usage discrepancy” banner under chart |
| Pins | `—— ACTIONS ——` · Refresh all · Open Cursor Spending |
| Footer | Settings… · About · Quit QuotAI |

## Extra (advanced) disclosure

Legend primary row (always): burn chips · … · Labels | Icons · **Advanced** (`ellipsis.circle`).  
Expanded adds a **second legend row** for Discrepancies, then the cluster strip below. Primary row does not reflow. Collapsed matches the live v0.18 panel. Clicking a chart band opens Advanced and the strip.

## Model → meter (Spending pools)

Per [legacy Cursor plans](https://cursor.com/docs/account/pricing/legacy-cursor-plans) / [usage limits](https://cursor.com/help/models-and-usage/usage-limits):

| Pool | Models |
| --- | --- |
| **Cursor Models** | Composer* · Grok* (agent) · Auto / `default` |
| **Other Models** | Third-party (Claude, GPT, Gemini, …) |

**Grok Bot** remains a separate weekly meter in QuotAI; discrepancy rows only use Cursor Models / Other Models.  
Live `CursorActivityParser` still maps only `modelId == "default"` → Cursor Models (everything else → Other) — that does **not** match this billing table yet.

## Winner → Swift

- Paint soft grey **bands** for clustered discrepancy periods on `PaceHistoryChart`
- Gate Discrepancies filter + expandable **strip** behind an **Extra** control on the burn legend row
- Keep the existing latest-event warning banner
- Branch `feat/discrepancy-chart-marks` after TDD seams confirmed
