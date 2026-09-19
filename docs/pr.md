# Product requirements — QuotAI

Last updated: 2026-09-19

## Goal

macOS menu-bar app showing **Cursor Models** and **Grok Bot** quota from Cursor Spending, plus a pace dial, with a Spending webpage escape hatch.

## v1 surface

- **Meters:** Cursor Models + Grok Bot only (`% used` + days left + pace). Other Models / on-demand → open Spending page.
- **Bar (Settings):** default Used + days left, or Pace dial (worse of two meters).
- **Dropdown:** always full detail + small dial per meter; always **Open Cursor Spending** → `https://cursor.com/dashboard/spending`.
- **Missing Grok:** error / unavailable row; Cursor Models still refresh.

## Auth

- Hybrid capture: auto-read Cursor `state.vscdb`, else paste.
- Keychain SoT: service `dev.marotron.QuotAI`, account `default`, JSON `{accessToken, refreshToken}`, `AfterFirstUnlockThisDeviceOnly`.
- Fail: one DB re-import → quiet menu **Re-auth from Cursor** / **Paste token…** / **Open Cursor Spending**.
- No auth-failure notifications in v1.

## Pace

- Live `%` on each fetch; one pace sample per meter per local day (production persistence).
- `r = percentUsed / (100 * t)`; green `0.90…1.10`; blue under; red over; early depletion menu-only.
- Strings: Under / On pace / Over / Exhausted / Pace n/a (+ `· ~Nd left` when early).

## Non-goals

- xAI Management API
- Extending AIMonitor
- Non-macOS
- Multi-account, App Store distribution, official Cursor API migration detail (fog)

## PoC learnings

See [`.scratch/quotai/issues/05-throwaway-poc.md`](../.scratch/quotai/issues/05-throwaway-poc.md). Connect + Desktop tokens work on this machine. Production path: Keychain + vscdb import + Connect refresh in the Swift app.
