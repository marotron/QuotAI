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
- Plan: live Connect fetch wired in Swift app (Keychain + vscdb + URLSession); polling locked (see Decisions).
- 2026-09-19 handoff: Wayfinder decisions 01–08 done; build session owns live fetch (not blocked on polling).
- 2026-10-24: About window shipped (#21); CI/CD on `main` (`docs/agents/ci-cd.md`).
- 2026-10-24: Signing / distribution strategy grilled and locked (GitHub #10 closed). Pretty DMG + Gatekeeper docs next ([issues/16-pretty-dmg-install-ux.md](issues/16-pretty-dmg-install-ux.md)).
- 2026-10-25: Pretty DMG 0.12.0 — Keychain Always Allow (usual) + optional Gatekeeper Open Anyway strip (`Scripts/release/dmg-assets/`).

## Decisions so far

- **Name the meters QuotAI surfaces** → v1 = Cursor Models + Grok Bot (`%` + days left) + per-meter pace; Other Models/on-demand out. Bar: Used+days (default) or Pace dial (worse meter; 0↔100%↔∞ log; green/red/blue). Missing Grok = error row. Dropdown always full + dials. See [issues/01-name-the-meters.md](issues/01-name-the-meters.md).
- **How Cursor Spending data is fetched today** → Connect `GetCurrentPeriodUsage` (`autoPercentUsed` + `billingCycleEnd`) and `GetSandUsageStatus` / REST sand twin for Grok Bot weekly `%`; IDE Bearer (+ cookie fallbacks). See [issues/02-research-cursor-spending-fetch.md](issues/02-research-cursor-spending-fetch.md).
- **Auth and secret storage** → Hybrid capture (vscdb then paste); Keychain SoT (`dev.marotron.QuotAI` / `default` / JSON tokens / device-only); fail → one DB re-import then quiet menu recovery; always **Open Cursor Spending** (`https://cursor.com/dashboard/spending`). See [issues/03-auth-and-secret-storage.md](issues/03-auth-and-secret-storage.md).
- **Burn-rate formula** → Live fetch for `%`/days; one pace sample/meter/local day; pace `r = percentUsed/(100*t)`; green `0.90…1.10`; early depletion menu-only (`~Nd left`); strings Under/On/Over/Exhausted/Pace n/a. See [issues/04-burn-rate-formula.md](issues/04-burn-rate-formula.md).
- **Throwaway PoC** → Live Connect fetch OK for both meters via `state.vscdb` Bearer; artifact `.scratch/quotai/poc/` (Python throwaway). See [issues/05-throwaway-poc.md](issues/05-throwaway-poc.md).
- **Product spec outline** → `docs/pr.md` + `docs/tech-specs.md` in QuotAI repo. See [issues/06-product-spec-outline.md](issues/06-product-spec-outline.md).
- **Production seams for TDD** → Test parse / pace / presentation; not network/Keychain in v1. See [issues/07-production-tdd-seams.md](issues/07-production-tdd-seams.md).
- **Scaffold production app shell** → Swift XcodeGen `MenuBarExtra` + `QuotAICore` (5 tests green). See [issues/08-scaffold-app-shell.md](issues/08-scaffold-app-shell.md).
- **Larger menu-bar dual-line text** → 10pt regular dual stack at ±4.5pt line centers with consistent tight tracking and faded reset time; debug preview covers three dials on light/dark backgrounds. Shipped `ae78731` / GitHub [#15](https://github.com/marotron/QuotAI/issues/15) closed. See [issues/11-menu-bar-text-size.md](issues/11-menu-bar-text-size.md).
- **Polling / refresh UX** → default poll 10 min (Settings: 5 / 10 / 15 / 30 min / 1 h); wake refresh; explicit **Refresh**; menu-open refresh if stale; RunLoop `Timer` + `ProcessInfo` activity (not `Task.sleep`). Pace sample still once/local day. See [issues/09-polling-refresh-ux.md](issues/09-polling-refresh-ux.md) / GitHub [#12](https://github.com/marotron/QuotAI/issues/12).
- **About QuotAI window** → version, short commit SHA, in-app changelog, GitHub Releases link; HTML prototype under `about-prototype/` (shipped). Merged [#21](https://github.com/marotron/QuotAI/pull/21).
- **CI/CD** → PR + `main` → `make test` (`ci.yml`); tag `v*` → `make test` then `make dmg` → GitHub Release. See [issues/14-ci-cd-pipeline.md](issues/14-ci-cd-pipeline.md) · [docs/agents/ci-cd.md](../../docs/agents/ci-cd.md).
- **Signing / distribution** → Near-term: GitHub Releases, ad-hoc DMGs, manual updates; notarization deferred. Eventual: website landing → Release DMG first (Homebrew + App Store stay options). Optional `QUOTAI_SIGN_*` unused until enroll. See [issues/15-signing-distribution-strategy.md](issues/15-signing-distribution-strategy.md) · GitHub [#10](https://github.com/marotron/QuotAI/issues/10) closed.
- **Pretty DMG + Keychain / Gatekeeper docs** → Dual-flow background (Keychain 1–3 + optional Gatekeeper 4–8) with live **Open QuotAI** and **Privacy & Security** applets in `Scripts/release/dmg-assets/`; README / RELEASE_BODY match. See [issues/16-pretty-dmg-install-ux.md](issues/16-pretty-dmg-install-ux.md).

## Not yet specified

GitHub mirrors (labels `roadmap` / `fog` / `next-version`):

- Multi-account support → [#9](https://github.com/marotron/QuotAI/issues/9)
- Official Cursor API migration path detail (when/if one ships) → [#11](https://github.com/marotron/QuotAI/issues/11)
- Pace dial visuals (log dial / colors) beyond text pace labels → [#13](https://github.com/marotron/QuotAI/issues/13)
- Custom notification banners (top-aligned icon + agent marks) — next version → [#8](https://github.com/marotron/QuotAI/issues/8) · [issues/10-custom-notification-ui.md](issues/10-custom-notification-ui.md)
- Pace band chart quick view (outside Settings → Alerts) — next version → [#16](https://github.com/marotron/QuotAI/issues/16) · [issues/12-pace-band-quick-view.md](issues/12-pace-band-quick-view.md)
- Historical used / elapsed trajectories (normalized period) — after quick view → [#17](https://github.com/marotron/QuotAI/issues/17) · [issues/13-pace-history-trajectories.md](issues/13-pace-history-trajectories.md)

## Out of scope

- xAI Management API / console.x.ai prepaid metering
- Extending AIMonitor in place (QuotAI is a new app)
- Non-macOS clients
- Non-Swift production implementations
- Low-quota / auth-failure **notifications** in v1 (pace early-depletion stays menu-only; already locked in auth + burn-rate tickets)
