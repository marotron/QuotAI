# Brand version history

Keeps prior QuotAI icon packs so `docs/brand/clear-b/` can move forward without losing older exports.

| Path | Role |
|------|------|
| [`PROGRESSION.md`](PROGRESSION.md) | Visual timeline with images |
| [`progression/`](progression/) | 128 / 256 thumbnails used by the progression doc |
| [`archive/`](archive/) | Source `.zip` exports from Icon Studio / v4pack |
| [`0.9.2/`](0.9.2/) | Flat pack as shipped with app **v0.9.2** |
| [`0.9.3/`](0.9.3/) | Flat pack for app **v0.9.3** (current) |
| [`drafts/`](drafts/) | One-off studio JSON presets (optional) |

## Live vs archive

- **Live (app + README):** `docs/brand/clear-b/`, `docs/brand/AppIcon.icns`, `docs/brand/app-icon*.png`, `QuotAI/Assets.xcassets/AppIcon.appiconset/`
- **History:** this folder — do not point Xcode at versioned copies

## When you ship a new icon pack

1. Copy the previous live flat pack into `docs/brand/versions/<old-version>/` (exclude `liquid-glass/`, studio HTML).
2. Drop the studio export zip into `archive/` with a clear name.
3. Extract `quotai-128.png` / `quotai-256.png` into `progression/` and add a section to `PROGRESSION.md`.
4. Replace live `clear-b/` + AppIcon assets, update `clear-b/settings.json` and `clear-b/README.txt`.
