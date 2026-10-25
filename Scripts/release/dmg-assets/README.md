# DMG install window assets

Used by `Scripts/release/dmg.sh` for the Finder install window (drag → Applications, plus Keychain / Gatekeeper copy).

| File | Role |
|------|------|
| `background.png` | Finder window background (2× Retina @ 144 DPI; height measured from `#canvas`) |
| `DS_Store` | Optional Finder layout blob (written by first local `make dmg`; used on CI) |
| `export.html` + `shots/` | Source for re-rendering the background |
| `render-background.swift` | Regenerates `background.png` (also prints icon-slot centers) |

Live Finder icons on the volume: **QuotAI.app** and **Applications** only. No helper applets — unsigned helpers get Gatekeeper-blocked the same way as the app.

## Install steps on the background

1. Drag **QuotAI** → **Applications**, then open QuotAI from Applications
2. Keychain → enter login password → **Always Allow** (usual after each new install)
3. If Gatekeeper blocks (optional): **Done** → System Settings → Privacy & Security → **Open Anyway**

## Re-render background

```bash
swift Scripts/release/dmg-assets/render-background.swift
```

Copy printed `icon-slot centers` into `dmg.sh` (`ICON_*`) if the layout moved. Delete `DS_Store` and run `make dmg` so Finder layout regenerates.
