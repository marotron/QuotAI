# Offline refresh notice experiment

Baseline SHA-256: `cdc6baba6800412daf639b896786d222dba662d906c853080cfe6e863dcfd0eb`.

2026-11-17: after an offline refresh, the live panel shows two orange text strings (Cursor `Refresh failed — offline` under the status row, Codex failure above the chart). Only Codex meter rows are dimmed. Requested direction: drop the top orange string, surface the failure below the chart in the discrepancy notice format, and dim meters (and soft-gray provider icons) that could not refresh so the kept readings do not look live.

## Compare

Open with `?offline=combined|current` (default `combined`). Appearance and Codex sample controls still apply. Dual orange strings (`#top-error`, `#mid-error`) are only shown under A for before/after; they must not ship in those positions.

| Option | Meaning |
| --- | --- |
| A · Current dual orange | Live chrome: top + mid orange strings; Codex-only dim |
| B · One notice below chart | Hide both orange strings; **exactly one** discrepancy-style offline notice that **names who failed**; dim only failed meters; amber age badges **only** for failed providers (+ Refresh all when any failed) |

Default seed: Cursor + Grok failed, Codex succeeded → Cursor/Grok badges amber, Codex badge normal, notice body starts with “Cursor and Grok could not refresh…”. Use the **Failed** control to compare All / Codex only. Do not show a second Codex refresh strip for the same offline event.

Menu-bar ring dimming is noted for native implementation; this panel prototype only covers the dropdown.

## Status

Approved for implementation 2026-11-17 (option B). Candidate `0.24.0-rc.6` ports the chrome: one named below-chart notice, per-provider amber badges + dimmed meters, blocked-usage in the same format. Live offline acceptance pending before promoting the dropdown baseline.
