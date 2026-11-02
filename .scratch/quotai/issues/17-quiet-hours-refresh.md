# Quiet hours for auto-refresh

Type: task
Status: open
Blocked by:
Target: next version
GitHub: https://github.com/marotron/QuotAI/issues/31

## Question

Add a **daily quiet-hours window** so automatic quota polling skips overnight (or any chosen span), plus a Settings toggle for **refresh on wake**.

## Locked decisions

- **Mode:** quiet hours — skip *automatic* polls inside the window (not “active hours only”).
- **Default:** quiet hours **off** until the user enables them and sets start/end times.
- **Manual always works:** explicit **Refresh** and dropdown `refreshIfStale()` still fetch during quiet hours.
- **Wake:** **Refresh on wake** stays **on by default**; expose as a Settings toggle so it can be turned off (e.g. to fully silence overnight).

## Placement

Settings → **Account**, near **Refresh rate** / **Dynamic refresh**:

- Toggle **Quiet hours** + start / end time (local clock; window may cross midnight).
- Toggle **Refresh on wake** (default on).

## Acceptance sketch

- [ ] When quiet hours are on and `now` is inside the window, the poll timer does not call `refresh()`
- [ ] Explicit Refresh and menu-open `refreshIfStale()` still fetch
- [ ] Wake-from-sleep refreshes when **Refresh on wake** is on (default); skips when off
- [ ] Quiet hours off by default; enabling shows start/end controls
- [ ] Times use the Mac’s local calendar / timezone
- [ ] Works with fixed intervals and Dynamic schedule alike

## Context

Extends the closed polling policy in [issues/09-polling-refresh-ux.md](09-polling-refresh-ux.md) / GitHub [#12](https://github.com/marotron/QuotAI/issues/12). Dynamic already tightens cadence near reset; quiet hours cap background traffic when nobody is looking.

## Comments

### 2026-10-25

User proposed a daily no-refresh window (e.g. overnight sleep). Grilling locked quiet hours (not active-only), off by default, manual always allowed, wake refresh on by default as a Settings option.

### 2026-10-25 (later)

Mirrored to GitHub [#31](https://github.com/marotron/QuotAI/issues/31).
