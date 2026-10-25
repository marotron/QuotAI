# Pretty DMG + Gatekeeper docs

Type: prototype
Status: resolved
Blocked by:
GitHub: [#23](https://github.com/marotron/QuotAI/issues/23)

## Question

Improve first-run install UX while builds stay ad-hoc signed: tighten Gatekeeper docs, and ship a prettier DMG (drag-to-Applications background + Privacy & Security affordance).

## Acceptance sketch

- [x] HTML (or equivalent) **pretty-DMG prototype** under `.scratch/quotai/` — layout, background art direction, webloc placement — approved before `dmg.sh` changes
- [x] Tighten README + `.github/RELEASE_BODY.md` (System Settings → Privacy & Security / Open Anyway + right-click Open)
- [x] Wire approved layout into `Scripts/release/dmg.sh` (background + Privacy & Security `.webloc` or equivalent)
- [x] QuotAI only first; MailGent copy later only if it feels right
- [x] No notarization / Developer Program work (see [15-signing-distribution-strategy.md](15-signing-distribution-strategy.md))

## Notes

- DMG background images are **not** clickable — Settings must be a file on the volume (e.g. `.webloc`) or docs.
- In-app Gatekeeper messaging: out of scope (Gatekeeper often blocks before launch).

## Comments

### 2026-10-24

Claimed after #10 strategy grill. Start with prototype.

### 2026-10-24 — expanded B flow

User prefers DMG layout **B** (arrow + Privacy webloc), with install path:

1. Drag QuotAI → Applications  
2. Try Open → Gatekeeper “Not Opened” (Done, not Move to Bin)  
3. DMG **Privacy & Security** webloc → Settings → **Open Anyway**  
4. Confirm **Open Anyway** → Touch ID / password  

Prototype: `.scratch/quotai/dmg-prototype/index.html` (+ `shots/01`–`04` from user’s screenshots).

User ask: put **all steps inside `.bg`** (embedded miniatures / key fragments), not separate panels — later flatten to one background PNG for `dmg.sh`.

## Answer

Shipped **0.12.0** dual-flow with helper applets; **0.12.1** simplified after Gatekeeper also blocked **Open QuotAI** / **Privacy & Security** applets:

- Live icons: **QuotAI.app** + **Applications** only (drag step).
- Background copy: Keychain **Always Allow** + optional Gatekeeper Open Anyway steps (no clickable helpers).
- Assets: `Scripts/release/dmg-assets/` (`background.png` 720×460 logical, `export.html`, renderer).
