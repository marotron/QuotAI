# Per-meter Dynamic refresh

Branch: `feat/per-meter-dynamic-refresh` · Plan: `~/.cursor/plans/per-meter_dynamic_refresh_a5971045.plan.md`

## Locked

- One Dynamic schedule; applied independently per family (Cursor Models+Other vs Grok Bot)
- Wake / Refresh all → both; Refresh Cursor / Grok Bot → that family only
- Fixed poll still fetches both on timer fire
- Status: `Last refresh: Cursor {HH:mm} · Grok Bot {HH:mm}` (24-hour; `—` when missing)
- Settings buttons: horizontal toolbar row (prototype variant C)
- Prototype: [per-meter-refresh-prototype/index.html](../per-meter-refresh-prototype/index.html)

## Seams

- `RefreshPlanner` + `LastRefreshStatus` in QuotAICore (tested)
- `RefreshSchedule.interval` unchanged
- Connect / QuotaStore / SwiftUI untested adapters

## Also in this ship

- Menu pins: Refresh all (default on), Refresh Cursor / Grok Bot (default off)

## Out of scope

- Quiet hours (#31)
- Two editable Dynamic schedules
- Stale-ring chrome
