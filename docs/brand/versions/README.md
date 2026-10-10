# Brand version history

Keeps prior QuotAI icon packs so `docs/brand/clear-b/` can move forward without losing older exports.

| Path | Role |
|------|------|
| [`PROGRESSION.md`](PROGRESSION.md) | Visual timeline with images |
| [`progression/`](progression/) | 128 / 256 thumbnails used by the progression doc |
| [`archive/`](archive/) | Source `.zip` exports from Icon Studio / v4pack |
| [`0.9.2/`](0.9.2/) | Flat pack as shipped with app **v0.9.2** |
| [`0.9.3/`](0.9.3/) | Flat pack for app **v0.9.3** |
| [`0.9.4/`](0.9.4/) | Flat pack for app **v0.9.4** (current) |
| [`drafts/`](drafts/) | One-off studio JSON presets (Paste JSON… in Icon Studio) |

### Drafts

| File | Notes |
|------|-------|
| [`drafts/settings-custom-tile-2026-10-09.json`](drafts/settings-custom-tile-2026-10-09.json) | Custom purple-black dark tile (`#390424` → `#1B042F`) |
| [`drafts/settings-frosted-open-eyes-2026-10-10.json`](drafts/settings-frosted-open-eyes-2026-10-10.json) | Frosted tile, open eyes (ratio 2.02), scale 1.28, gap 8, face 144 |
| [`drafts/settings-frosted-open-eyes-ratio-1.41-2026-10-10.json`](drafts/settings-frosted-open-eyes-ratio-1.41-2026-10-10.json) | Frosted trial; rounder eyes (ratio 1.41) — face params fed **v0.9.4** / pack 6 (black tile) |

## Live vs archive

- **Live (app + README):** `docs/brand/clear-b/`, `docs/brand/AppIcon.icns`, `docs/brand/app-icon*.png`, `QuotAI/Assets.xcassets/AppIcon.appiconset/`
- **History:** this folder — do not point Xcode at versioned copies

## When you ship a new icon pack

1. Copy the previous live flat pack into `docs/brand/versions/<old-version>/` (exclude `liquid-glass/`, studio HTML).
2. Drop the studio export zip into `archive/` with a clear name.
3. Extract `quotai-128.png` / `quotai-256.png` into `progression/` and add a section to `PROGRESSION.md`.
4. Replace live `clear-b/` + AppIcon assets, update `clear-b/settings.json` and `clear-b/README.txt`.
