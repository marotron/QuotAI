# QuotAI

macOS menu-bar app for Cursor Spending quota: Cursor Models, Other, and Grok Bot. Pace shows as rings and blinks.

## Install

**[Download QuotAI-0.7.0.dmg](https://github.com/marotron/QuotAI/releases/download/v0.7.0/QuotAI-0.7.0.dmg)** · [latest release](https://github.com/marotron/QuotAI/releases/latest)

1. Open the disk image.
2. Drag **QuotAI** to **Applications**.
3. Open QuotAI from Applications. It lives in the menu bar.

The 0.7.0 build is ad-hoc signed (hardened runtime off). If macOS blocks the first launch, right-click **QuotAI** in Applications → **Open**, then confirm.

## Screenshots

![QuotAI menu bar rings](docs/screenshots/menu-rings.gif)

Menu bar rings (used % and time to reset). Nested Cursor blinks between Models and Other; a smart pace hit blinks that quota ring. [Original recording](docs/screenshots/menu-rings.mov).

Display (ring style, beside-meter labels, ring center):

![QuotAI Settings — Display](docs/screenshots/settings-display.png)

Smart pace alert corridors:

![QuotAI Settings — Alerts](docs/screenshots/settings-alerts.png)

Menu pins, including Open Cursor Spending:

![QuotAI Settings — Menu pins](docs/screenshots/settings-pins.png)

## Features

- **Rings** for used % and time to reset: one meter each, nested Cursor (Models + Other), or pace segments.
- **Nested Cursor** blinks between Models and Other. A smart pace hit blinks the quota ring that crossed the alert.
- **Smart pace alerts** use an on-pace band, with a menu blink, a macOS notification, and optional email.
- **Open Cursor Spending** opens [cursor.com/dashboard/spending](https://cursor.com/dashboard/spending) from the menu.
- **Settings** cover ring style, beside-meter labels, ring center, alert corridors, and which rows stay pinned.

## Requirements

macOS 14 or later. Cursor must be signed in on this Mac, or paste a token under Settings → Account.

## Troubleshooting

- **Empty meters.** Sign in to Cursor, then choose **Refresh** on the QuotAI menu. Or Settings → Account → **Re-auth from Cursor**.
- **Auth error.** The menu says “Auth error — re-auth or paste token”. Use **Re-auth from Cursor** or **Paste token…**. Tokens stay in Keychain.
- **Refresh failed.** The menu keeps the last meters and shows the error (offline, timeout, or HTTP). **Refresh** again when the network is back. A sign-in failure replaces the menu-bar icon until you re-auth.

## Build

For contributors:

```bash
make project   # xcodegen generate
make test      # QuotAICore unit tests
open QuotAI.xcodeproj
```

The app is `QuotAI/` and `QuotAICore/`. Paths under `.scratch/` are not part of the build.

## Release

```bash
make dmg        # package only → dist/QuotAI-<version>.dmg
make release    # run tests, then package
```

Optional, once a Developer ID certificate and a notary keychain profile exist:

```bash
export QUOTAI_SIGN_IDENTITY='Developer ID Application: …'
export QUOTAI_NOTARY_PROFILE='quotai-notary'
```

Without those, the DMG is ad-hoc signed and needs the right-click → Open step above.

## License

[MIT](LICENSE)
