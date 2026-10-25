## Install

1. Download `QuotAI-*.dmg` below.
2. Open the disk image — the window walks through install, Keychain, and (if needed) Gatekeeper steps.
3. Drag **QuotAI** → **Applications**.
4. Double-click **Open QuotAI** on the DMG (or open QuotAI from Applications). Menu bar only — no Dock icon by default.
5. When Keychain asks for your login password, enter it and press **Always Allow**.
6. If Gatekeeper blocks the first open, follow the optional strip on the DMG (or the steps below).

## Keychain prompt

QuotAI stores LLM API keys in the macOS **Keychain**. Expect this after each new install / version. macOS asks for your **login** password the first time the app reads them. That is normal — not a Gatekeeper block. Choosing **Always Allow** means you will not see this prompt on every launch.

## macOS Gatekeeper (unsigned builds)

**This DMG is unsigned/ad-hoc unless the release workflow had `QUOTAI_SIGN_IDENTITY` and `QUOTAI_NOTARY_PROFILE` repository secrets set.** On other Macs, Gatekeeper may still show *“QuotAI Not Opened”* / *“was blocked to protect your Mac”* on first launch. Skip this section if QuotAI opens fine.

**Bypass (once):**

1. In the block dialog click **Done** (not Move to Bin).
2. Double-click **Privacy & Security** on the DMG (or open **System Settings → Privacy & Security**).
3. Press **Open Anyway**, confirm, then unlock with **Touch ID** or an administrator **password**.

On older macOS, right-click **QuotAI** → **Open** → confirm may still work.

Notarized builds (Developer ID + Apple notarization) will remove this step when signing secrets are configured.

## Requirements

- macOS 14+
- Cursor signed in on this Mac, or a token under Settings → Account
