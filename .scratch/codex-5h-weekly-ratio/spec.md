# Codex 5h→7d ratio tracker (experimental)

Decision: 2026-11-17. Status: **shipped in 0.24.0**.

## Locked

- No live ratio chip on the Codex · 5h meter row.
- Opt-in Settings → Account → Codex toggle **Track Codex 5h→7d ratio (experimental)**, default off.
- Open a period only after short-window used % > 0. Codex starts the ≈5h window on first use; idle polls often show a floating `resetsAt` (~full duration ahead) that must not open or close records.
- Closed-period math only: when an **opened** ≈5h window’s `resetsAt` changes, append one permanent record. Idle `resetsAt` drift with used % ≤ 0 writes nothing.
- Identify windows by duration (≈5h / ≈7d), never by primary/secondary slot.
- JSON at `~/Library/Application Support/dev.marotron.QuotAI/codex-5h-weekly-ratio.json`. Genuine samples are append-only forever. Exception: on load, purge idle artifacts (`incompleteReason == peakZero` or `peak5h ≤ 0`). Disconnect / toggle-off stop recording only.
- Persist `shortDurationSeconds` on close (fallback 5h for older rows) so a selected row can map onto the live 7d elapsed axis.
- UI: chart Advanced popover tabs **Discrepancies** (cluster-based) | **Codex 5h→7d** (closed-period list). Clicking a ratio row selects it and paints a teal vertical band over that 5h slice on the Codex · 7d elapsed axis when the slice intersects the live long window. Selection clears when Advanced closes or when leaving the Codex tab. No zoom / chart→list reverse click in this pass.
- Discrepancies chip lives in the legend with burn controls; Advanced is tabbed content only.

## Formula

- `peak5h` = max observed short-window used % while open
- `weeklyDelta` = weeklyEnd − weeklyStart (long-window used %)
- Skip implied % when the long window’s `resetsAt` changes mid-period, usage is missing, or `peak5h ≤ 0`
- Otherwise `impliedWeeklyPctForFull5h = weeklyDelta / (peak5h / 100)`

## Out of scope

Notifications, live chip, pruning UI / delete broom, export, chart↔list reverse click, zoom-to-band.
