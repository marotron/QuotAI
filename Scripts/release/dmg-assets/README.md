# DMG install window assets

Used by `Scripts/release/dmg.sh` for the pretty Finder window (Keychain Always Allow + optional Gatekeeper Open Anyway).

| File | Role |
|------|------|
| `background.png` | Finder window background (1440×1104 @ 144 DPI = 720×552 logical; Retina) |
| `Open QuotAI.app` | AppleScript applet → `open /Applications/QuotAI.app` (Step 2 click target) |
| `Privacy & Security.app` | AppleScript applet → System Settings → Privacy & Security (Step 5) |
| `DS_Store` | Optional Finder layout blob (written by first local `make dmg`; used on CI) |
| `export.html` + `shots/` | Source for re-rendering the background |
| `render-background.swift` | Regenerates `background.png` (also prints icon-slot centers) |
| `make-privacy-icon.swift` | Regenerates the Privacy applet icon |
| `privacy.icns` | Privacy applet icon source |

A `.webloc` cannot open `x-apple.systempreferences:` URLs (Launch Services rejects them). The applet runs `open` on that URL instead.

## Install steps on the background

**Usual (every new install / version)**

1. Drag **QuotAI** → **Applications**
2. Double-click **Open QuotAI** on the DMG
3. Keychain → enter login password → **Always Allow**

**If Gatekeeper blocks (optional)**

4. In the block dialog click **Done** (not Move to Bin)
5. Double-click **Privacy & Security** on the DMG
6. In Settings → Privacy & Security → **Open Anyway**
7. Confirm → **Open Anyway**
8. Unlock with **Touch ID** or administrator **password**

## Re-render background

After editing `export.html` or screenshots:

```bash
swift Scripts/release/dmg-assets/render-background.swift
```

Copy the printed `icon-slot centers` into `dmg.sh` (`ICON_*`) if the layout moved. Icon slots in the export are empty on purpose — live Finder icons sit on top.

## Rebuild the Open QuotAI applet

```bash
osacompile -o "Scripts/release/dmg-assets/Open QuotAI.app" <<'EOF'
try
  do shell script "test -d /Applications/QuotAI.app"
  do shell script "open /Applications/QuotAI.app"
on error
  display dialog "Drag QuotAI into Applications first (step 1), then try again." buttons {"OK"} default button 1 with icon caution with title "Open QuotAI"
end try
EOF

cp docs/brand/AppIcon.icns \
  "Scripts/release/dmg-assets/Open QuotAI.app/Contents/Resources/applet.icns"
codesign --force --sign - "Scripts/release/dmg-assets/Open QuotAI.app"
```

## Rebuild the Settings applet

```bash
osacompile -o "Scripts/release/dmg-assets/Privacy & Security.app" <<'EOF'
try
  do shell script "open 'x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension'"
on error
  do shell script "open 'x-apple.systempreferences:com.apple.preference.security'"
end try
EOF

ICONSET="$(mktemp -d)/privacy.iconset"
swift Scripts/release/dmg-assets/make-privacy-icon.swift "$ICONSET"
iconutil -c icns "$ICONSET" -o Scripts/release/dmg-assets/privacy.icns
cp Scripts/release/dmg-assets/privacy.icns \
  "Scripts/release/dmg-assets/Privacy & Security.app/Contents/Resources/applet.icns"
codesign --force --sign - "Scripts/release/dmg-assets/Privacy & Security.app"
rm -rf "$(dirname "$ICONSET")"
```

After changing either applet or icon, delete `DS_Store` and run `make dmg` so Finder layout is regenerated.
