# Menu bar dual-line text size

Type: task
Status: resolved
Blocked by:
Target: next version
GitHub: https://github.com/marotron/QuotAI/issues/15

## Question

Make the **used % / remaining** dual-line text beside menu-bar rings a bit larger — closer to typical weather-app menu extras (stacked °C) — while keeping the 22pt ring row readable and not overcrowding three dials.

## Context

- **Now:** `RingIcon.Metrics.dualFont` is 8pt monospaced-digit semibold; single-line beside is 11pt; remaining beside is 9pt (`QuotAI/RingIcon.swift`).
- User reference: current QuotAI dual stack feels small vs weather menu item stacked numbers that fill more of the menu-bar height.
- Constrained by menu-bar height (~22pt) and three dials (Cursor / Other / Grok) sharing one status item.

## Acceptance sketch

- [ ] Dual used+elapsed (or used+days) stack ~weather-app scale — larger than 8pt without clipping or colliding with rings
- [ ] Single-line and center-in-ring modes still balanced (no oversized orphan glyphs)
- [ ] Three-dial layout still fits a typical menu bar without truncating mid-glyph
- [ ] Optional: Settings control (Small / Medium) only if one size cannot satisfy both preferences
- [ ] Visual check on retina + non-retina; dark / light menu bar

## Comments

### 2026-10-09

User asked to schedule larger menu-bar dual text for a future version (compare current dual %/days vs weather stacked °).

### 2026-10-09 (later)

Mirrored to GitHub [#15](https://github.com/marotron/QuotAI/issues/15).

## Answer

Status: resolved

- Increased the dual-stack font from 8pt semibold to 10pt regular, retaining ±4.5pt line centers.
- Centralized both controls as `dualFontSize` and `dualLineOffset` in `RingIcon.Metrics`; single-line, remaining-column, and ring-center typography are unchanged.
- Applied consistent tightened tracking to percentage and reset-time labels; percentages use equal emphasis while reset time is faded.
- Added a debug-only Xcode Canvas preview in `QuotAI/RingIconPreview.swift` with three representative dials on light and dark menu-bar backgrounds.
- Rendered the three-dial sample at 1× and 2× with no text clipping or ring collision.
- Checked alternating elapsed/reset phases for one, two, and three dials; their widths remain stable.
- `make test` and the full QuotAI app build pass.

GitHub issue [#15](https://github.com/marotron/QuotAI/issues/15) closed 2026-10-24 — shipped on `main` as `ae78731`.
