# Pace history chart zoom — prototype

**Status:** Approved — **Variant A** (brush + ×N badge).  
**Prototype:** [`index.html`](index.html) · `?variant=A|B|C`  
**Shipped behaviour:** menu pace chart X-only zoom (see plan `pace_chart_zoom_3cc6d07a`).

## Shared rules (all variants)

| Rule | Choice |
| --- | --- |
| Axis zoomed | **Elapsed % (X) only** — Y stays 0…100 |
| Cap | **×10** (minimum visible span = 10 elapsed points) |
| Nested zoom | Yes (brush again inside a zoomed view) |
| Host chrome | Approved MenuBarExtra panel shell |

## Variants

| Key | Name | Zoom in | Zoom out / reset | Chrome when zoomed |
| --- | --- | --- | --- | --- |
| **A** ✓ | Brush + ×N badge | Drag L↔R selection → expand | ×N Reset badge · double-click · Esc | Top-left ×N Reset badge |
| **B** | Scroll zoom + pan | Wheel / trackpad toward pointer; drag to pan | Click ×N badge · double-click · Esc | Tiny ×N badge |
| **C** | Brush + context rail | Same brush as A | Click outside rail window · double-click · Esc | Thin overview strip (pan by dragging window) |

## Open

```bash
open .scratch/quotai/pace-history-zoom-prototype/index.html
```
