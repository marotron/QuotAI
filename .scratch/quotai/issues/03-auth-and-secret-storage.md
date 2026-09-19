# Auth and secret storage

Type: grilling
Status: resolved
Blocked by: 02

## Question

How should Marek supply Cursor session / token credentials to QuotAI, where are they stored, and what happens when flaky auth dies?

Cover at least:

- Capture path (paste cookie/token, browser helper, copy from Cursor app, other)
- Keychain item shape (service name, account, accessibility)
- Refresh / re-auth UX when the unofficial path fails
- Whether Spending webpage deep-link is always available as fallback

Why it matters: PoC and production shell both need a locked secret story before any live fetch.

## Answer

**Capture:** Hybrid — auto-read Cursor Desktop `state.vscdb` (`cursorAuth/accessToken` + refresh) first; paste fallback when that fails.

**Storage:** Keychain is source of truth after capture. Normal polls and `oauth/token` refresh read/update Keychain only. On auth failure (`401` / `shouldLogout` / refresh fails) → one auto re-import from `state.vscdb`, then paste / Open Spending if that fails. Re-read DB otherwise only when Keychain is empty or user chooses **Re-auth from Cursor**.

**Keychain:** One item — service `dev.marotron.QuotAI`, account `default`, value JSON `{accessToken, refreshToken}` (optional `cachedEmail`). Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. UI email may also be a non-secret preference. Multi-account stays in fog.

**Re-auth UX:** Quiet auth-error row; menu actions **Re-auth from Cursor**, **Paste token…**, **Open Cursor Spending**. No interruptive sheet unless user picks Paste/Re-auth. No auth-failure notifications in v1.

**Spending link:** Always in the dropdown (healthy or error). URL: `https://cursor.com/dashboard/spending`.

## Comments

### Progress (grilling)

- **Capture path:** Hybrid — auto-read Cursor `state.vscdb` first; paste fallback when that fails.
- **Storage:** Keychain is source of truth after capture (access + refresh). Normal polls and oauth refresh read/update Keychain only. On auth failure (`401` / `shouldLogout` / refresh fails) → one auto re-import from `state.vscdb`, then paste sheet / Open Spending if that fails. Re-read DB otherwise only when Keychain is empty or user chooses “Re-auth from Cursor”.
- **Keychain shape:** One item — service `dev.marotron.QuotAI`, account `default`, value JSON `{accessToken, refreshToken}` (+ optional `cachedEmail`). Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Email for UI may also live as a non-secret preference.
- **Re-auth UX:** Quiet menu error + actions — auth-error row in bar/menu; **Re-auth from Cursor**, **Paste token…**, **Open Cursor Spending**. No interruptive sheet unless user picks Paste/Re-auth. No auth-failure notifications in v1 (alerts stay in fog).
- **Spending deep-link:** Always in dropdown; `https://cursor.com/dashboard/spending`.
