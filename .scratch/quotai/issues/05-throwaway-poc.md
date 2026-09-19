# Throwaway PoC

Type: prototype
Status: resolved
Blocked by: 02, 03, 04

## Question

Build a minimal throwaway proof that live Cursor Spending data can be read for both meters: Cursor Models `%` + reset, and Grok Bot `%` + reset.

Acceptable forms: CLI print, or a tiny menu-bar stub. Delete or ignore after learning — do not keep as production code.

Success: one successful fetch of both meters with credentials from the agreed auth path; document what broke along the way.

Use `/prototype`. Link any PoC path under `.scratch/quotai/` or a throwaway branch.

## Answer

**Artifact:** [`.scratch/quotai/poc/`](../poc/) — `python3 .scratch/quotai/poc/fetch_meters.py`

**Result (2026-09-19 ~19:33 local):** Success for both meters with Cursor Desktop `state.vscdb` Bearer → Connect (no refresh needed this run).

| Meter | % used | Days left | Pace label (sample) |
|-------|--------|-----------|---------------------|
| Cursor Models | ~70.0 | 1 | Under · 70% pace |
| Grok Bot | ~46.9 | 5 | Over · 139% pace · ~3d left |

**What worked:**
- Read `cursorAuth/accessToken` (+ refresh present) from `state.vscdb`
- `GetCurrentPeriodUsage` → `planUsage.autoPercentUsed` + billing cycle bounds
- `GetSandUsageStatus` → `usagePercent` + `currentPeriodStart` / `nextResetTimestampUtc`
- Pure pace helper matched locked formula (green band, early depletion string)

**What broke / skipped:**
- PoC did **not** write Keychain (import-only). Production still must implement Keychain SoT + fail re-import.
- Sandbox blocked reading `~/Library` until run outside sandbox — expect Full Disk / non-sandboxed or user-selected access for production.
- No paste-fallback path exercised.
- No oauth refresh exercised (access token valid).

**Verdict:** Unofficial Connect path is good enough for v1 PoC; always keep Spending deep-link.
