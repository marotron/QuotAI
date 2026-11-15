# Window prototype workflow

Decision: 2026-11-15, requested by the user. UI work starts from a maintained window or element baseline, with an isolated copy for each experiment. The repository keeps these baselines as design references; this user instruction takes precedence over the generic prototype skill's throwaway-only baseline policy.

## Location and coverage

Open `.scratch/quotai/window-prototypes/index.html` for the catalog. One command from the repository root:

```sh
open .scratch/quotai/window-prototypes/index.html
```

- `baselines/dropdown/`: copied from the existing `.scratch/quotai/pace-history-menu-prototype/` dropdown and updated for rc.11 after the rc.10 native light/dark preview comparison. Native source: `QuotAI/MenuBarWindowPanel.swift`, plus `CodexQuotaViews.swift`. The real native reference is also available with `make preview`.
- `baselines/settings/`: six-tab seeded HTML reference for `SettingsView.swift`. Initial coverage; rc.11 places Codex rules below Grok. Native Settings comparison, secondary controls and detailed notes need reconciliation.
- `baselines/about/`: source-based HTML reference for `QuotAIAboutView`; application icon is a placeholder until captured.
- `baselines/changelog/`: working-tree changelog content in a browser approximation of `QuotAIChangelogView`.
- Existing element studies, including ring dimensions and menu pins, are linked from the catalog.

The native Settings content is 460 × 620 pt, About is 400 pt wide, dropdown is 470 pt wide, and Changelog has a 480 × 420 pt minimum. Browser material, font metrics, SF glyph rasterization and chart details can differ. References are **not verified pixel-equivalent baselines**; the dropdown has a seeded native light/dark comparison. The catalog and manifest record this explicitly. Browser OAuth pages and OS permission sheets are external surfaces rather than QuotAI-owned windows.

## Iteration and promotion

1. Find the corresponding baseline. If missing or incomplete for the affected area, reconcile it with source and the current native window first. Capture seeded, non-sensitive examples of loading, missing data and errors relevant to the change.
2. Copy the baseline directory into `experiments/<change>/`, keeping assets local. Record the baseline identity/source hash and the design question. Implement the experiment in this copy; show A/B or before/after on the same route.
3. Review the prototype with the user. Keep proposed behavior visibly distinct from implemented behavior. A diagram is not approval, and a prototype must not silently change the app's contract.
4. After the user chooses the change, implement it in the app and update specifications in the same change set. Follow candidate versioning for product edits. Run required checks and compare the actual native window against the proposal.
5. Once implementation is verified, update the corresponding baseline from the final implementation, including the relevant states. Update `manifest.json`, the catalog, source hashes and verification evidence. Keep the experiment's verdict and lineage; do not label an unverified experiment as the new baseline.
6. When shipping is authorized, ensure affected window baselines match the shipped behavior. Commit baseline/experiment changes under the repository's existing authorization policy; do not auto-commit or auto-publish from this workflow.

A baseline is an implementation reference, not a frozen promise that old behavior can never change. The application specifications remain the behavior contract.

## Current experiment

`experiments/codex-matrix/index.html?matrix=1` proposes adding Codex windows to the existing used ÷ elapsed = pace · status → reset matrix. `?matrix=0` shows the current separate block. The user approved variant B on 2026-11-15. The frozen copy is `locked/codex-matrix-2026-11-15/`; native light/dark preview comparison was completed and the dropdown baseline updated for rc.10; further state acceptance remains pending. It adds no live chart data or notifications. Preset status symbols are illustrative rather than a port of the full corridor evaluator. The original chart prototype supplies historical chart chrome, with seeded trajectories adjusted to the screenshot readings.
