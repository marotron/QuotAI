# Changelog

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
