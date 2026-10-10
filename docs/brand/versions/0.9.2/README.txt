QuotAI clear-b  (frosted clear tile, grey mascot, artwork scale 1.28)

NO LIQUID GLASS (default / legacy: macOS < 26, iOS < 26, web)  ->  the DARK icon
  QuotAI.svg / QuotAI-macos.svg / QuotAI-ios.svg   SVG masters (flat tile / macOS 824 grid / iOS full-bleed)
  png/                         quotai-16 ... quotai-1024
  macOS/AppIcon.appiconset     + macOS/AppIcon.icns
  iOS/AppIcon.appiconset       single 1024 'any' image (opaque). Optional: iOS 18+ Contents.json can add
                               entries with "appearances": [{"appearance": "luminosity", "value": "dark"}] or
                               "tinted" pointing at extra 1024 PNGs - not included, the dark icon is used for all.
  web/                         favicon.ico/.svg, 16/32 PNG, apple-touch-icon, 192/512 + maskable, site.webmanifest
  Dark icon = white elapsed ring, 3D light-grey mascot, frosted tile baked over neutral dark grey.

LIQUID GLASS (macOS/iOS 26+)  ->  liquid-glass/
  QuotAI-clear-b.icon/         Icon Composer bundle (icon.json + Assets/ flat layers). icon.json is set up with the
                               light-appearance ring + mascot; use the *-dark-appearance ring and mascot layers for
                               the dark appearance in Icon Composer. Open and re-save in Icon Composer to verify.
  layers/                      SVG + PNG layers, all aligned 1024 full-bleed:
                               0-tile-frost, 1-quota-band, 2-elapsed-ring-light/dark-appearance, 3-pace-hand,
                               4-grey-mascot-light/dark-appearance
  light-appearance/            full flat set of the light look (dark #46464F ring + flat mascot, baked over light grey):
                               svg/, png/, macOS/, iOS/, web/ - reference/extra, not the primary icon.

Real 'clear' see-through needs the system compositor; flat PNG/ICNS/iOS assets bake the frost over a neutral background.
