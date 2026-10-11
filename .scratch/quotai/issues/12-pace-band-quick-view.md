# Pace band chart quick view

Type: task
Status: open
Blocked by:
Target: next version
GitHub: https://github.com/marotron/QuotAI/issues/16

## Question

Expose a **quick view** of the smart-pace used×elapsed band chart (same corridors + meter dots as Settings → Alerts / `PaceAlertBandChart`) without opening Preferences and navigating to Alerts.

## Context

- Chart already lives in Settings (`PaceAlertBandChart`): used % vs elapsed %, even-pace diagonal, over/under corridors, Cursor / Other / Grok dots.
- Menu pin **On-pace band** (`pinOnPaceBand`) is a different control (dropdown pin), not the square band chart.
- User wants a glance at that graph from the menu bar / dropdown.

## Acceptance sketch

- [ ] Quick view shows the same band geometry and live meter positions as Settings → Alerts
- [ ] Reachable without opening Settings (exact chrome: grill — dropdown row, popover, glance panel)
- [ ] Updates with the latest successful refresh
- [ ] Does not duplicate alert threshold controls (those stay in Settings)

## Follow-on

Historical used/elapsed trajectories → [issues/13-pace-history-trajectories.md](13-pace-history-trajectories.md) · GitHub [#17](https://github.com/marotron/QuotAI/issues/17).

## Comments

### 2026-10-09

User asked for a quick view of the Settings → Alerts smart pace graph; historical trajectories as a later upgrade.

### 2026-10-09 (later)

Mirrored to GitHub [#16](https://github.com/marotron/QuotAI/issues/16).
