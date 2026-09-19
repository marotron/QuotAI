# QuotAI Wayfinder

Label: wayfinder:map

## Destination

A written product spec plus a working macOS menu-bar app that shows remaining **Cursor** and **Grok Bot** quota from Cursor Spending, built TDD-first under YAGNI→KISS→DRY→SOLID — with a throwaway PoC before the real app.

## Notes

- **Stack:** Swift / SwiftUI `MenuBarExtra` / XcodeGen on macOS 14+ only. Throwaway PoC scripts are not production.
- Product truth comes from Cursor Spending UI (screenshots), not the xAI Management API.
- Consult `wayfinder`, `grilling` / `domain-modeling` for HITL tickets, `prototype` for PoC, `tdd` + `kiss-dry-solid-yagni` for app tickets.
- Credentials live in Keychain only.
- Em dash ban does not apply to vault idea docs or this map.
- Always offer a link to the Spending webpage; unofficial fetch path is acceptable and flaky until Cursor ships an official API.
- Idea case: `~/Personal/04-ideas/05-quotai/`
- Plan: live Connect fetch wired in Swift app (Keychain + vscdb + URLSession); polling UX still fog (`issues/09-polling-refresh-ux.md`).
- 2026-09-19 handoff: Wayfinder decisions 01–08 done; build session owns live fetch (not blocked on polling).

## Decisions so far

- **Name the meters QuotAI surfaces** → v1 = Cursor Models + Grok Bot (`%` + days left) + per-meter pace; Other Models/on-demand out. Bar: Used+days (default) or Pace dial (worse meter; 0↔100%↔∞ log; green/red/blue). Missing Grok = error row. Dropdown always full + dials. See [issues/01-name-the-meters.md](issues/01-name-the-meters.md).
- **How Cursor Spending data is fetched today** → Connect `GetCurrentPeriodUsage` (`autoPercentUsed` + `billingCycleEnd`) and `GetSandUsageStatus` / REST sand twin for Grok Bot weekly `%`; IDE Bearer (+ cookie fallbacks). See [issues/02-research-cursor-spending-fetch.md](issues/02-research-cursor-spending-fetch.md).
- **Auth and secret storage** → Hybrid capture (vscdb then paste); Keychain SoT (`dev.marotron.QuotAI` / `default` / JSON tokens / device-only); fail → one DB re-import then quiet menu recovery; always **Open Cursor Spending** (`https://cursor.com/dashboard/spending`). See [issues/03-auth-and-secret-storage.md](issues/03-auth-and-secret-storage.md).
- **Burn-rate formula** → Live fetch for `%`/days; one pace sample/meter/local day; pace `r = percentUsed/(100*t)`; green `0.90…1.10`; early depletion menu-only (`~Nd left`); strings Under/On/Over/Exhausted/Pace n/a. See [issues/04-burn-rate-formula.md](issues/04-burn-rate-formula.md).
- **Throwaway PoC** → Live Connect fetch OK for both meters via `state.vscdb` Bearer; artifact `.scratch/quotai/poc/` (Python throwaway). See [issues/05-throwaway-poc.md](issues/05-throwaway-poc.md).
- **Product spec outline** → `docs/pr.md` + `docs/tech-specs.md` in QuotAI repo. See [issues/06-product-spec-outline.md](issues/06-product-spec-outline.md).
- **Production seams for TDD** → Test parse / pace / presentation; not network/Keychain in v1. See [issues/07-production-tdd-seams.md](issues/07-production-tdd-seams.md).
- **Scaffold production app shell** → Swift XcodeGen `MenuBarExtra` + `QuotAICore` (5 tests green). See [issues/08-scaffold-app-shell.md](issues/08-scaffold-app-shell.md).

## Not yet specified

- Multi-account support
- App Store vs personal signing / distribution
- Official Cursor API migration path detail (when/if one ships)
- Polling / background refresh cadence (ticket open: [Polling and refresh UX](issues/09-polling-refresh-ux.md))
- Pace dial visuals (log dial / colors) beyond text pace labels

## Out of scope

- xAI Management API / console.x.ai prepaid metering
- Extending AIMonitor in place (QuotAI is a new app)
- Non-macOS clients
- Non-Swift production implementations
- Low-quota / auth-failure **notifications** in v1 (pace early-depletion stays menu-only; already locked in auth + burn-rate tickets)
