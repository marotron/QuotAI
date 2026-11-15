# Window prototypes

Open `index.html`, or run `open .scratch/quotai/window-prototypes/index.html` from the repo root.

See [the workflow](../../../docs/agents/ui-prototypes.md) for baseline coverage, native source mapping, review and promotion rules. `manifest.json` records the source snapshot and pending verification. Dropdown and Codex matrix copies retain the original menu prototype's chart and local assets. Settings, About and Changelog are initial browser references, with incomplete areas explicitly marked in the catalog.

The Codex experiment supports A/B comparison (`?matrix=0|1`), light/dark appearance, and current/over/exhausted/missing/stale samples. The approved matrix and header were implemented in candidate 0.21.0-rc.10; the dropdown baseline reflects the seeded native preview.

The Codex matrix experiment (B) uses icons instead of provider names in the top refresh line and includes Codex time, age and refresh glyph there. The separate freshness row is removed. A preserves the current layout for comparison. Checked in the browser at 470 CSS px on 2026-11-15.

The refresh-header revision adds Perplexity as a future-provider sample and a leading refresh symbol. All four fixed-width age badges are buttons: hover/focus fades the age upward and reveals a rotating refresh arrow; clicking shows a short busy animation then updates the seeded timestamp/age. Reduced-motion preferences disable transitions/spinning. Browser checks confirmed the four-provider header fits at 470 CSS px and Perplexity click changes its sample timestamp to 12:47. No live refresh or provider integration is added.

The global refresh control now uses the same 11 × 11 px single-arrow mark as each provider badge, its own hover/focus button treatment and a vertical separator before Cursor. Clicking it runs the simulated refresh for all four providers together; individual badge actions remain available. Verified the header fits at 470 CSS px and all four sample timestamps update to 12:47.
