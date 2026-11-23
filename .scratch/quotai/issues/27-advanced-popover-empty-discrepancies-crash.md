# Advanced popover crash with empty discrepancies

Status: resolved  
Date: 2026-11-22

## Symptom

QuotAI 0.23.0 (build 90) quit unexpectedly when opening pace-chart **Advanced** (ellipsis) on macOS 15.7.7.

Crash: `EXC_BREAKPOINT` in `PaceHistoryChart.discrepancyStrip.getter` while SwiftUI measured the popover (`NSPopover.effectiveContentSize` → `sizeThatFits`).

## Cause

0.23.0 always embedded `discrepancyStrip` in the Advanced popover. `selectedCluster` fell back to `discrepancyClusters[0]`, which traps when the list is empty.

Not an OS-version SwiftUI bug — empty-cluster indexing; newer OS simply exercised the popover layout path the same way.

## Fix

- Show “No discrepancies” when clusters are empty (already on main for the Discrepancies tab).
- Make `selectedCluster` optional via `discrepancyClusters.first` — never subscript `[0]`.
- `discrepancyStrip` guards on that optional so popover measurement cannot trap.

Shipped: `0.24.1` (build 100).
