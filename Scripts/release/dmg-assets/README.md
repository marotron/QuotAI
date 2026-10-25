# DMG install window assets

Used by `Scripts/release/dmg.sh` for the Finder install window (drag → Applications, plus Keychain / Gatekeeper copy).

| File | Role |
|------|------|
| `background.png` | Finder window background (2× Retina @ 144 DPI; height measured from `#canvas`) |
| `DS_Store` | Optional Finder layout blob (written by first local `make dmg`; used on CI) |
| `Open QuotAI` | Fallback Finder alias → `/Applications/QuotAI.app` (CI / when AppleScript cannot remake it) |
| `export.html` + `shots/` | Source for re-rendering the background |
| `render-background.swift` | Regenerates `background.png` (also prints icon-slot centers) |

Live Finder icons on the volume: **QuotAI.app**, **Applications**, and **Open QuotAI**. No helper applets.

**Alias caveats:** plain `cp` strips `FinderInfo` so the file becomes a Document and opens as raw bookmark text. Git checkout also drops FinderInfo. Stage with `ditto` + `SetFile -a A -t fapa -c MACS` — type/creator alone is not enough; without the alias bit Finder shows a blank icon and “used by macOS and can’t be opened.” Remake via Finder AppleScript only when `/Applications/QuotAI.app` exists; otherwise keep the staged bookmark (CI). Never delete the staged alias before remake succeeds.

## Install steps on the background

1. Drag **QuotAI** → **Applications**, then double-click **Open QuotAI** (or open from Applications)
2. Keychain → enter login password → **Always Allow** (usual after each new install)
3. If Gatekeeper blocks (optional): **Done** → System Settings → Privacy & Security → **Open Anyway**

## Re-render background

```bash
swift Scripts/release/dmg-assets/render-background.swift
```

Copy printed `icon-slot centers` into `dmg.sh` (`ICON_*`) if the layout moved. Delete `DS_Store` and run `make dmg` so Finder layout regenerates.
