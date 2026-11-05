# Changelog

## 0.17.2 — 2026-11-05

### Changed

- Elapsed hover tip appends the elapsed share to the billing period, e.g. `Elapsed billing period: 53m of 7d → 1.23%`, with 2-decimal percent

## 0.17.1 — 2026-11-05

### Added

- Pace chart `Icons` toggle: show or hide the series avatars at the end of each line and in the hover tip, independent of `Labels`

### Changed

- Pace chart legend: `Over corridor` / `Under corridor` → `Over burn` / `Under burn`; `Exact pace` → `Ideal pace`; `Names` → `Labels`
- Burn chips use custom swatches: a blue band on top for under burn, an orange band on the bottom for over burn
- Legend chips grouped: `Over burn | Under burn | Ideal pace` and `Labels | Icons`, with hairline dividers between buttons; the visibility group wraps below the corridor group when the chart is narrow
- `Labels` and `Icons` no longer show eye icons; hidden chips dim instead

### Fixed

- Pace chart layer toggles stay as you set them after a reading refresh instead of resetting to all shown

## 0.17.0 — 2026-11-04

### Added

- Menu pins: choose rows in Settings → Menu pins to show in the menu bar dropdown (Refresh all, Refresh Cursor, Refresh Grok Bot, Refresh interval, Open Cursor Spending, Menu bar style, Color mode, Show Other Models, Beside meter toggles, Center, Blink on significant pace)
- Pinned dropdown rows read and write the same settings as Settings, in both directions; sections are titled in the rule (`—— ACTIONS ——`), with a vertical divider between the two columns in Compact
- Settings → Menu pins → Dropdown layout: `Compact` (smaller text, pinned rows in two columns, switches aligned in a vertical line) or `Normal` (regular text, one column)
- Dropdown rows use one text size and style: Compact matches the `Show icons` size, Normal matches Settings; hover highlight is menu blue with a white label; menu pickers show their current value with an up/down chevron instead of a bordered pop-up button

### Changed

- Settings help text on every tab uses the Alerts note style (caption, secondary, bulleted) and sits under the control, group, or tab it describes; notes match current behavior

## 0.16.0 — 2026-11-03

### Added

- Hover tooltips on meter-row facts: usage shows `Used quota` with 2-decimal percent, elapsed shows the billing period as a duration (`24d 21h of 30d`), pace shows `used ÷ elapsed` with 2-decimal percent
- Design-preview app target (`QuotAIPanelPreview`) with seeded meters/history for look-only panel iteration

### Changed

- Pace history chart axes: all ticks read as percentages, y title is `Used`, x title `Elapsed` sits between the 75% and 100% labels, `100%` right-aligned near the axis end
- Hover tip reworked: `Elapsed N%` leads on its own line, readings include clock time in compact form (`26 Oct 14:32`), divider before the corridor bands, corridor values read `N% used`, all text one shared smaller size, values same color/weight as the rest
- Hover circles on the chart match the current end-cap dots (halo + core) instead of oversized singles

### Fixed

- Ago freshness chips no longer truncate (`just…` → `just now`) and meter titles render in full (`Cursor Models`)
- Meter metric cluster stays flush right across rows even with full-length titles

## 0.15.4 — 2026-11-03

### Fixed

- Window panel meter title reads "Cursor Models" instead of "Models", matching the label used everywhere else
- Pace band end label for Cursor Models reads "Cursor" instead of "Models"

## 0.15.3 — 2026-11-02

### Fixed

- Re-auth / import works again with Cursor 3.27+ sealed editor tokens (`cursor-safe-storage`) by opening them with the local Cursor Safe Storage key

## 0.15.2 — 2026-11-02

### Changed

- Header version chip uses the same white-on-blue hover/press as panel action rows

## 0.15.1 — 2026-11-02

### Changed

- Status-row ago chips are per-family freshness badges: age-tinted inverse pie, hover SF Symbol refresh, click refreshes Cursor or Grok Bot without blanking the row
- Meter used / elapsed / pace / reset facts align in fixed trailing columns across rows

## 0.15.0 — 2026-11-02

### Added

- Menu bar **window panel** (Swift Charts): per-quota meters, pace history (used % vs elapsed %), corridor filters, hover tip, and actions
- Pace history sample store + chart model (Cursor / Grok series, exact-pace guide, over/under corridors)
- Version label in the panel header opens the in-app changelog; About stays in the actions list

### Changed

- MenuBarExtra uses `.window` panel chrome instead of the native menu for meters and history
- Ring/bar chrome and Settings Alerts copy follow **corridor alerts** only (quiet → neutral; under/over/exhausted tint); on-pace band removed from chart, legend, tip, meters, and Settings
- About link labeled **GitHub release notes**

## 0.14.0 — 2026-10-26

### Added

- Per-family Dynamic refresh: one schedule, independent Cursor vs Grok Bot cadence; Refresh all / Refresh Cursor / Refresh Grok Bot
- Status line `Last refresh: Cursor {HH:mm} · Grok Bot {HH:mm}` (24-hour) in menu and Settings → Account
- Menu pins for Refresh all (on by default), Refresh Cursor, and Refresh Grok Bot

### Changed

- Dynamic help copy: each quota uses the schedule from its own time to reset (no longer “soonest reset” only)

## 0.13.2 — 2026-10-25

### Fixed

- DMG install row: align **Open QuotAI** icon slot with the drag-row icons (matched padding/border; Finder overlay Y)

## 0.13.1 — 2026-10-25

### Fixed

- DMG **Open QuotAI** alias survives CI: do not delete the staged bookmark before remaking when `/Applications/QuotAI.app` is missing (empty step 2 on 0.13.0)
- DMG **Open QuotAI** alias: set Finder alias bit (`SetFile -a A`) when staging so CI builds are double-clickable (blank icon / “used by macOS” without it)

## 0.13.0 — 2026-10-25

### Added

- DMG **Open QuotAI** Finder alias (launches the app from Applications after drag-install)

### Changed

- DMG install row: drag → Applications (2/3) beside Open QuotAI (1/3)

## 0.12.3 — 2026-10-25

### Fixed

- About no longer opens the Changelog window at the same time (menu click / resurrected closed window)

### Changed

- Menu labels shortened (Settings / About / Quit) with separators between them; About actions use Changelog / Release notes

## 0.12.2 — 2026-10-25

### Fixed

- DMG step 1 card: more clearance below QuotAI / Applications icons

## 0.12.1 — 2026-10-25

### Fixed

- Simplified DMG to drag → Applications only (unsigned helper applets were Gatekeeper-blocked too); Keychain and Open Anyway guidance stay as background copy

## 0.12.0 — 2026-10-25

### Added

- Pretty DMG install window: Keychain flow (drag → open → **Always Allow**) plus optional Gatekeeper strip (**Done** → **Privacy & Security** → **Open Anyway**), with live **Open QuotAI** and **Privacy & Security** shortcuts on the disk image

## 0.11.0 — 2026-10-21

### Added

- About QuotAI window (version, short commit SHA, in-app changelog, GitHub Releases link)

## 0.10.0 — 2026-10-19

### Changed

- Enlarged the dual-line percentages and reset times beside menu-bar rings for easier reading

## 0.9.5 — 2026-10-13

### Fixed

- Ring/bar chrome: smart under/over wins color (and blinks); if smart is quiet, on-pace band sets solid blue/green/orange (e.g. Other under-corridor → blue blink even when ratio is still in the on-pace band)

### Added

- [Pace chrome](docs/pace-chrome.md) doc — decision order diagram + scenario matrix (linked from README)

## 0.9.4 — 2026-10-10

### Changed

- App icon refresh (clear-b pack 6: scale 1.33, black charcoal tile `#2B2833` → `#000000`, open eyes ratio 1.41)

## 0.9.3 — 2026-10-10

### Changed

- App icon refresh (clear-b pack: artwork scale 1.35, dark purple-black tile `#390424` → `#1B042F`, sphere look/eye tweaks)
- Brand pack history under `docs/brand/versions/` (archived zips + visual [`PROGRESSION.md`](docs/brand/versions/PROGRESSION.md))

## 0.9.2 — 2026-10-09

### Changed

- App icon refresh (clear-b sphere mascot, updated gradient pack for Finder / Dock / About / notifications)

## 0.9.1 — 2026-10-09

### Changed

- Pace alert notifications and email use compact copy (`Cursor · Grok over`, `▲ Cursor 74% / 66%`)
- App icon from QuotAI clear-b pack (grey mascot, frosted clear tile; dark primary for Finder / Dock / About; liquid-glass sources under docs/brand/clear-b)

## 0.9.0 — 2026-10-09

### Added

- App icon (Finder / Dock / About) from the QuotAI icon pack

## 0.8.0 — 2026-10-09

### Added

- Dynamic refresh: polls faster as the soonest quota reset gets closer, with a schedule edited in minutes, hours, or days (Settings → Account)

### Fixed

- Smart-over (and exhausted) paints alarm orange on every ring look, not only by-pace rings

## 0.7.1 — 2026-09-24

### Fixed

- Dropdown time to reset and the pace estimate follow the clock between refreshes, at most once a minute
- Menu-bar time to reset uses that same minute clock
- Time to reset rounds down, so the menu bar and dropdown show the same minute
- Quota and elapsed percents round half up (`15.5` → `16`, `15.49` → `15`)
- Dropdown elapsed percent uses the same two-decimal precision as quota used

## 0.7.0 — 2026-09-23

### Added

- Cursor and Grok marks inside rings, pace-tinted, with the white holes left transparent
- Other Models ring shows its icon in one-per-meter when Center is Icon
- Significant-pace blink on the quota ring that crossed the alert (same pattern as bars)
- Alternate elapsed % ↔ time to reset on every ring style, including one per meter
- Open Cursor Spending menu pin

### Changed

- Pace rings: brighter quota green, muted under-slack, orange over; both arcs go solid orange on a smart over alert
- Thicker by-pace rings, thin separators between segments, white elapsed separator
- Tighter tracking on percent labels beside the meters
- A failed refresh stays in the menu notice; the rings keep the last meters (sign-in failure still replaces the icon)

### Fixed

- One-per-meter Cursor dial no longer swaps its center icon
- Avatar tint stays on the mark

## 0.6.0 — 2026-09-22

### Added

- Ring-dial menu-bar looks: per-quota, nested Cursor (Models + Other), and pace-segment rings
- Ring center options (none / time to reset / icon) and beside-meter elapsed %
- Alternate elapsed % ↔ time to reset in one beside slot (rings)
- Under↔over conflict: center/beside icon slowly pulses between the two pace colors (synced with nested used %)

### Changed

- Menu-bar fills and ring arcs use pace colors (under blue / on green / over orange) instead of fixed brand tints
- Over-pace tint matches smart-alarm orange (exhausted stays red)
- Display settings: Beside meter / Ring center groups; elapsed and center options only for ring looks

### Fixed

- Nested Cursor dial used % and under↔over center icon share one blink phase

## 0.5.0 — 2026-09-21

### Added

- Over/under curve dials (linear → parabolic); under mirrors over across even pace; curves clamped to parallels through Full quota before / Min usage by period end

### Fixed

- Pace notify/email re-checks when corridor dials change (blink was live; banners were not)
- Alert status text only claims “sent” when delivery actually succeeded this attempt
- Menu-bar timeline inset and early-period fill stub so used vs elapsed share one scale

### Changed

- Band chart: square used×elapsed plot, Used % on the trailing edge, meter dots grey until under (blue) / over (orange)
- Corridor group titles spaced above dials

## 0.4.1 — 2026-09-21

### Fixed

- Settings opens in front from the menu bar (LSUIElement window raise)
- macOS notification banners while Settings is open (foreground `UNUserNotificationCenter` delegate)
- Alert cooldown only after notify/email delivery succeeds

### Changed

- Narrower Settings window with denser percent dials and shorter band chart
- Alerts tab: test notification control grouped under the notifications toggle

## 0.4.0 — 2026-09-21

### Added

- Smart pace-band alerts: linear over/under corridors with cooldown-gated macOS notifications and SMTP email
- Settings window (Display, Pace, Alerts, Email, Menu pins) with live band chart
- Percent dials for smart-alert threshold knobs

### Changed

- Blink and alert significance use smart bands when enabled (legacy pace ratios remain as a fallback)
- Menu dropdown slimmed to meters, actions, pinned prefs, Settings, and Quit

## 0.3.0 — 2026-09-20

### Added

- Structured menu meter rows with ice/fire/on-pace band marks
- Secondary pace notes: projected unused quota, or empties-in / idle-days when over pace

### Changed

- Menu presentation returns `meters` + `notices` instead of plain string rows
- Native `.menu` style; notes rendered as separate NSMenu items so they are not stripped
- Menu bar always uses used + days; removed Bar mode picker / pace glance mode
- Dropdown pace marks: ❄ / ✓ / ♨ with pace colors via `NSMenuItem.attributedTitle`
- Significant-pace blink half-cycle slowed to 1s (~2s full period)

## 0.2.0 — 2026-09-20

### Added

- Live Cursor Spending fetch in the macOS menu-bar app (Keychain + `state.vscdb` import + Connect `URLSession`)
- Pure Connect JSON → meter parsers in `QuotAICore` (unit-tested)
- Auth recovery menu actions: Refresh, Re-auth from Cursor, Paste token…, Open Cursor Spending
- Spending-style % display, pace bar colors, and menu-bar icon toggle
- Thin billing-period timeline under menu-bar quota bars
- Live used/elapsed pace in the menu, with optional blink on significant pace
- Remaining time shows hours when under one day (`5h` vs `1d`)

### Changed

- Menu-bar quota thickness matched for single/dual meters; Cursor stacks outlined once
- Dropped daily pace-sample freeze so menu math matches current usage
- Icon animation isolated so blink ticks do not dismiss pickers

### Fixed

- Stopped tracking Xcode build output and user state in git

## 0.1.0 — 2026-09-19

### Added

- XcodeGen Swift macOS `MenuBarExtra` scaffold + `QuotAICore` pace/presentation seams
