# Historical used / elapsed trajectories

Type: task
Status: open
Blocked by: [12-pace-band-quick-view.md](12-pace-band-quick-view.md)
Target: next version (after quick view)
GitHub: https://github.com/marotron/QuotAI/issues/17

## Question

On the pace glance surface, add **history**: plot each quota’s **used %** (Y) against **normalized period time / elapsed %** (X); similarly for **elapsed** history.

## Context

- Today’s band chart is a snapshot of current meter positions vs smart corridors.
- History would show burn trajectories for Cursor / Other / Grok across the billing or reset period.
- Needs local sample persistence; period reset should clear or roll history.

## Acceptance sketch

- [ ] Persist per-meter samples (used %, elapsed %, timestamp) for the active period
- [ ] Plot used % vs normalized elapsed % per quota
- [ ] Comparable series / view for elapsed over the period
- [ ] Period reset clears or rolls history for the new cycle
- [ ] Samples stay local (no cloud sync in first cut)
- [ ] Surfaced via the quick-view chrome, not Settings-only

## Open questions

- Sample cadence (every refresh vs once per local day)
- Overlay on band corridors vs separate chart mode
- Retention across app restarts

## Comments

### 2026-10-09

User described historical used (and elapsed) vs normalized time as the upgrade after the band-chart quick view.

### 2026-10-09 (later)

Mirrored to GitHub [#17](https://github.com/marotron/QuotAI/issues/17).
