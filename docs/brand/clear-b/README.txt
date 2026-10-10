QuotAI clear-b  (sphere mascot, blue→orange quota band, artwork scale 1.35)

Primary (Finder / Dock / About / notifications): DARK appearance from Icon Studio export.
  Tile: black style with custom purple-black gradient (#390424 → #1B042F)
  Ring: light elapsed track; OKLCH gradient band (#3478F7 → #F19A38); orange pace hand
  Face: 3D light-grey sphere mascot (look ~122°, eye size 1.4)

TOOL
  quotai-icon-studio.html   live SVG generator (open in a browser)
  settings.json             last exported studio preset (Paste JSON… in the studio)

HISTORY
  ../versions/              prior packs + source zips (do not point Xcode here)
  ../versions/PROGRESSION.md  visual timeline with images

NO LIQUID GLASS (default / legacy: macOS < 26, iOS < 26, web)  ->  the DARK icon
  QuotAI.svg / QuotAI-macos.svg / QuotAI-ios.svg   SVG masters (flat tile / macOS 824 grid / iOS full-bleed)
  png/                         quotai-16 ... quotai-1024
  preview.png                  256px flat preview
  macOS/AppIcon.appiconset     + macOS/AppIcon.icns
  iOS/AppIcon.appiconset       single 1024 'any' image (opaque). Optional: iOS 18+ Contents.json can add
                               entries with "appearances": [{"appearance": "luminosity", "value": "dark"}] or
                               "tinted" pointing at extra 1024 PNGs - not included; the dark icon is used for all.
  web/                         favicon.ico/.svg, 16/32 PNG, apple-touch-icon, 192/512 + maskable, site.webmanifest

Also copied for the live app / README:
  ../../AppIcon.icns, app-icon.png (512), app-icon-128.png
  ../../quotai-icon.svg, quotai-icon-macos.svg
  ../../../QuotAI/Assets.xcassets/AppIcon.appiconset/

LIQUID GLASS (macOS/iOS 26+)  ->  liquid-glass/
  QuotAI-clear-b.icon/         Icon Composer bundle (icon.json + Assets/ flat layers). icon.json is set up with the
                               light-appearance ring + mascot; use the *-dark-appearance ring and mascot layers for
                               the dark appearance in Icon Composer. Open and re-save in Icon Composer to verify.
  layers/                      SVG + PNG layers, all aligned 1024 full-bleed:
                               0-tile-frost, 1-quota-band, 2-elapsed-ring-light/dark-appearance, 3-pace-hand,
                               4-grey-mascot-light/dark-appearance
  light-appearance/            full flat set of the light look - reference/extra, not the primary icon.

  Note: liquid-glass layer SVGs may lag the flat studio pack above. Re-export layers from Icon Studio /
  Icon Composer when shipping a liquid-glass update. Flat PNG/ICNS/iOS assets bake the tile; real clear
  see-through needs the system compositor.
