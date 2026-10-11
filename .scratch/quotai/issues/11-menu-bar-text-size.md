# Menu bar dual-line text size

Type: task
Status: open
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
