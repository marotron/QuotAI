# Changelog

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
