# Codex 5h→7d ratio · Advanced tabs

Baseline SHA-256: see `baseline-sha256.txt` (dropdown baseline at copy time).

## Design question

How should closed Codex 5h→7d ratio records read inside the chart **Advanced** popover, with the Discrepancies chip living in the legend and Settings Account opt-in copy?

## Proposed (not shipped)

- No live ratio chip on the Codex · 5h meter row.
- Legend matches live controls plus Codex: Cursor / Grok / Codex corridor icons, then burn chips (swatch = chart corridor fills at 16% transparent; labels expand on hover). Labels / Icons stay icon-only. Discrepancies chip sits in `legend-primary` next to the burn group.
- Advanced (ellipsis) popover is tabbed: **Discrepancies** | **Codex 5h→7d**.
- **Discrepancies tab is cluster-based** (same model as the live `discrepancyStrip`): a set of clusters, one cluster shown at a time with ← / → (“Cluster N of M”), event count badge, period label, elapsed span, and the event list for that cluster. Tab badge = total events across clusters. Do not design this tab as a single flat list of all events.
- Codex tab: ~26 pt rows, ~120 pt max scroll height.
- Row: `12 Nov 14:02 · peak 97% · Δ7d +18.4% · ≈19.0% of 7d`; incomplete rows state why.
- Empty: tracking off → “Tracking off”; on with no closes → “No closed 5h periods yet”.
- Settings → Account → Codex: **Track Codex 5h→7d ratio (experimental)**, default off; footnote that records persist and the list lives under Advanced → Codex 5h→7d.

## Open

```sh
open .scratch/quotai/window-prototypes/experiments/codex-5h-weekly-ratio/index.html
```

`?ratio=seeded|empty|off` · `?adv=disc|ratio` · click Advanced ellipsis · Settings card below the stage.
