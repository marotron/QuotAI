# How Cursor Spending quota data is fetched today

**Date:** 2026-09-19  
**Ticket:** [How Cursor Spending data is fetched today](../issues/02-research-cursor-spending-fetch.md)  
**Scope:** Unofficial / private dashboard paths for **Cursor Models** (monthly) and **Grok Bot** (weekly). Out of scope: xAI Management API / console.x.ai.

**Confidence:** High for endpoint names, auth shapes, and field mapping used by mature third-party clients (OpenUsage, Pulse, OpenQuota). Medium that live Spending UI network traffic matches those clients byte-for-byte (no authenticated DevTools capture in this pass). Low for official stability — Cursor does not document these as public APIs.

---

## Executive summary

For QuotAI’s product meters (Spending UI: Cursor Models % + monthly reset; Grok Bot weekly % + days left):

| UI meter | Primary fetch | Key fields |
|---|---|---|
| **Cursor Models** (% used, monthly reset) | Connect RPC `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage` | `planUsage.autoPercentUsed`; reset from `billingCycleEnd` |
| **Other Models** (related pool, not QuotAI primary) | Same RPC | `planUsage.apiPercentUsed`; same `billingCycleEnd` |
| **Grok Bot** (% used, weekly) | Connect RPC `POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus` **or** REST twin `POST https://cursor.com/api/dashboard/get-sand-usage-status` | `usagePercent`; optional `nextResetTimestampUtc` / `currentPeriodStart` |

Auth for Connect RPCs: Bearer access token from Cursor’s local session store (or refreshed via OAuth). Auth for `cursor.com` REST: cookie `WorkosCursorSessionToken` (and POST CSRF needs `Origin: https://cursor.com`).

There is **no official public “Spending API”** for individuals. Third parties reverse-engineer the same DashboardService / dashboard routes the web app uses.

---

## Product truth (official UI / docs)

Cursor’s help docs state:

- Individual plans have two **monthly** pools: **Cursor Models** and **Other Models**.
- Usage is checked on the **Spending** tab (`https://cursor.com/dashboard/spending`); reset is monthly with the billing cycle; unused usage does not roll over.
- Grok Bot has a **separate weekly** included allowance metered on the Cursor account (not SuperGrok / xAI console).

Sources: [Usage and limits](https://cursor.com/help/models-and-usage/usage-limits), [Grok Bot plans](https://cursor.com/help/grok-bot/plans), forum confirmation that Grok Bot weekly quota is separate from Cursor Models monthly ([forum thread](https://forum.cursor.com/t/are-grok-bot-usage-and-cursor-usage-separate/170875)).

Unauthenticated GET of `/dashboard/spending` redirects to login (`307` → `/api/auth/login?redirect_uri=…dashboard/spending`) — observed 2026-09-19.

---

## Auth / session

### Preferred path (IDE token → Connect RPC)

Third-party clients read Cursor Desktop’s SQLite state DB:

- **macOS path:** `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- **Keys:** `cursorAuth/accessToken`, `cursorAuth/refreshToken` (also `cursorAuth/cachedEmail`, membership keys)

Documented by OpenTokenUsage / OpenUsage-style reverse-engineering notes:

```bash
sqlite3 ~/Library/Application\ Support/Cursor/User/globalStorage/state.vscdb \
  "SELECT value FROM ItemTable WHERE key = 'cursorAuth/accessToken'"
```

Source: [PowerUserZ OpenTokenUsage cursor.md](https://raw.githubusercontent.com/PowerUserZ/OpenTokenUsage/main/docs/providers/cursor.md); OpenUsage provider docs at [openusage.sh/docs/providers/cursor](https://openusage.sh/docs/providers/cursor/) and [robinebers/openusage docs](https://github.com/robinebers/openusage/blob/main/docs/providers/cursor.md).

**Connect request headers** (OpenUsage `CursorUsageClient.connectPost`):

- `Authorization: Bearer <access_token>`
- `Content-Type: application/json`
- `Connect-Protocol-Version: 1`
- Body: `{}`

Source: [CursorUsageClient.swift on main](https://raw.githubusercontent.com/robinebers/openusage/main/Sources/OpenUsage/Providers/Cursor/CursorUsageClient.swift).

**Token refresh** when JWT expires:

```
POST https://api2.cursor.sh/oauth/token
Content-Type: application/json

{
  "grant_type": "refresh_token",
  "client_id": "KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB",
  "refresh_token": "<refresh_token>"
}
```

Success returns `access_token` / `id_token`; `shouldLogout: true` means re-login in Cursor. Same client ID appears in OpenQuota. Sources: OpenTokenUsage cursor.md; [OpenQuota client.rs](https://github.com/deviffyy/OpenQuota/blob/f9d2884c/src-tauri/src/providers/cursor/client.rs).

### Web / REST cookie path

Dashboard REST calls use:

```
Cookie: WorkosCursorSessionToken=<userId>%3A%3A<access_token>
```

`userId` is derived from JWT `sub` (strip provider prefix after `|`). OpenUsage builds the same cookie from the IDE access token for `cursor.com/api/usage-summary`, `/api/usage`, `/api/auth/stripe`, CSV export.

POST endpoints on `cursor.com` require `Origin: https://cursor.com` or return invalid-origin CSRF errors. Source: [dmwyatt gist](https://gist.github.com/dmwyatt/1e9359b1862e7cbfe1e754fe4c8db764); Pulse Grok Bot docs (see below).

---

## Endpoints

### 1. Cursor Models (monthly) — primary

```
POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage
```

Connect RPC, empty JSON body, Bearer auth as above.

**Fields that map to Spending UI “Cursor Models”:**

| Concept | Field | Notes |
|---|---|---|
| % used (Cursor Models) | `planUsage.autoPercentUsed` | OpenUsage **renamed** UI label from “Auto usage” → “Cursor Models” to match dashboard ([PR #1134](https://github.com/robinebers/openusage/pull/1134)) |
| % used (Other Models) | `planUsage.apiPercentUsed` | Dashboard label “Other Models” (was “API usage”) |
| Combined / total % | `planUsage.totalPercentUsed` | Separate “Total Usage” meter |
| Monthly reset | `billingCycleEnd` (and `billingCycleStart`) | OpenUsage treats as cycle end for `resetsAt`; OpenTokenUsage documents unix-ms strings; some docs also mention RFC3339 — treat as opaque and parse both |
| Dollar spend / limit | `planUsage.{totalSpend,includedSpend,bonusSpend,remaining,limit}` | Cents; useful for burn math, not required for % meters |

Example payload shape (OpenTokenUsage):

```jsonc
{
  "billingCycleStart": "1768399334000",
  "billingCycleEnd": "1771077734000",
  "planUsage": {
    "autoPercentUsed": 0,
    "apiPercentUsed": 46.444,
    "totalPercentUsed": 15.48,
    "totalSpend": 23222,
    "limit": 40000
  },
  "spendLimitUsage": { /* on-demand */ }
}
```

Sources: OpenTokenUsage cursor.md; OpenUsage mapper (`autoPercentUsed` → label `"Cursor Models"`, `resetsAt: cycle.resetsAt` from billing cycle) in [commit 65324c6](https://github.com/robinebers/openusage/commit/65324c6c04c169cc8024f9ab47912dc3718b7027) / current `CursorUsageMapper.swift`.

### 2. Grok Bot (weekly) — primary

Two equivalent surfaces (Pulse measured REST and RPC as byte-identical on one account):

**A. Connect RPC (OpenUsage / Bearer):**

```
POST https://api2.cursor.sh/aiserver.v1.DashboardService/GetSandUsageStatus
```

Same Connect headers + `{}` body. Cursor’s internal product name is **“Sand”**.

**B. Dashboard REST (Pulse / cookie):**

```
POST https://cursor.com/api/dashboard/get-sand-usage-status
Cookie: WorkosCursorSessionToken=…
Origin: https://cursor.com
Body: {}
```

**Fields:**

| Concept | Field | Notes |
|---|---|---|
| % used | `usagePercent` | 0…100 “gone”; **absent ≠ 0** — hide meter if missing |
| Reset time | `nextResetTimestampUtc` | ISO8601 when present; often **missing** |
| Period start | `currentPeriodStart` | Do **not** invent reset as start+7d (Pulse: vendor client does not) |
| Eligibility gates | `usesPooledEnterpriseAllowance`, `hasNonZeroIncludedLimit`, `includedLimitZero` | Hide personal meter when pooled / zero included |

OpenUsage mapping (PR #1134): require not pooled, not zero included, finite `usagePercent`; set `resetsAt` from `nextResetTimestampUtc` when parseable; period length from start→reset or fallback week duration for UI math.

Sources: [OpenUsage PR #1134](https://github.com/robinebers/openusage/pull/1134), [commit 65324c6](https://github.com/robinebers/openusage/commit/65324c6c04c169cc8024f9ab47912dc3718b7027), [Pulse Docs/providers/grok-bot.md](https://raw.githubusercontent.com/qunqin24/Pulse/main/Docs/providers/grok-bot.md), official weekly reset wording at [cursor.com/help/grok-bot/plans](https://cursor.com/help/grok-bot/plans).

### 3. Fallbacks (Enterprise / team / sparse planUsage)

When `GetCurrentPeriodUsage` lacks usable `planUsage`:

| Endpoint | Auth | Role |
|---|---|---|
| `GET https://cursor.com/api/usage-summary` | Cookie | Structured `%` + billing cycle; also carries `individualUsage.plan.autoPercentUsed` / `apiPercentUsed` |
| `GET https://cursor.com/api/usage?user=<userId>` | Cookie | Legacy request counts (often Enterprise) |
| `GET https://api2.cursor.sh/auth/usage` | Bearer (some clients) | Alternate request-bucket shape |

OpenUsage issue [#829](https://github.com/robinebers/openusage/issues/829) and PR #846 document enterprise/team needing `/api/usage-summary` when Connect `planUsage` is empty. Gist documents usage-summary response including the same percent fields under `individualUsage.plan`.

For QuotAI’s individual Pro-style Spending screenshot truth, **Connect `GetCurrentPeriodUsage` + `GetSandUsageStatus` are the first targets**; REST fallbacks matter for robustness.

### 4. Related (not needed for the two meters)

Documented by OpenUsage / OpenQuota but secondary for QuotAI v1:

- `GetPlanInfo`, `GetHardLimit`, `GetCreditGrantsBalance`, `GetAggregatedUsageEvents`, `GetUsageLimitPolicyStatus`, `GetTeamMembers`
- `GET https://cursor.com/api/auth/stripe`
- `GET https://cursor.com/api/dashboard/export-usage-events-csv` (spend history imputation)

---

## Failure modes

| Failure | Evidence | Client behaviour to expect |
|---|---|---|
| No / expired Bearer on Connect | Live probe 2026-09-19: `POST …/GetCurrentPeriodUsage` without auth → **HTTP 401**, body `{"code":"unauthenticated",…,"error":"ERROR_NOT_LOGGED_IN",…}` | Refresh token once; if `shouldLogout`, require Cursor re-login |
| No session cookie on REST | Live probe: `GET https://cursor.com/api/usage-summary` → **401** `{"error":"not_authenticated",…}` | Same as above / copy cookie from token |
| Wrong HTTP method on Connect | Live probe: bare GET → **405** | Always POST + Connect headers |
| Missing CSRF Origin on `cursor.com` POST | Gist / Pulse | `Invalid origin for state-changing request` |
| Missing plan fields | OpenUsage docs | Omit meter / “No data”; Enterprise may need usage-summary fallback |
| Grok Bot ineligible / pooled / no `usagePercent` | OpenUsage + Pulse | Hide meter; do not show 0% as “full green” for non-included plans |
| Missing `nextResetTimestampUtc` | Pulse measurement | Show % without days-left, or only show days when field present — **do not invent** reset from start+7d |
| Optional endpoint failure | OpenUsage | Keep primary Cursor Models data; log Grok Bot failure as nonfatal |
| Rate limits | Gist: unknown | Be conservative; no documented quota found |
| Cloudflare / bot blocks | Not hit on `api2.cursor.sh` unauth probe this pass; web dashboard behind Vercel login redirect | Prefer API host over scraping Spending HTML |
| Unofficial API churn | All reverse-eng docs | Expect breakage; keep Spending deep-link as user escape hatch |

---

## AIMonitor check (negative)

Local `AIMonitor` is **not** a Cursor Spending fetch path. `AIMonitor/Models.swift` calls:

- `https://openrouter.ai/api/v1/auth/key` (OpenRouter API key stats)
- `https://generativelanguage.googleapis.com/v1beta/models?key=…` (Gemini)

No `api2.cursor.sh` / `cursor.com/api` usage. Confirmed by ripgrep of the Swift sources (2026-09-19).

---

## What this pass did / did not verify

**Did:**

- Cite OpenUsage source + docs for Connect URLs, headers, field→UI mapping (Cursor Models = `autoPercentUsed`, Grok Bot = `GetSandUsageStatus`).
- Cite Pulse for REST twin `get-sand-usage-status` and reset-field caveats.
- Cite Cursor official help for monthly vs weekly product meaning and Spending URL.
- Probe unauthenticated failure responses on Connect + usage-summary.
- Confirm AIMonitor is OpenRouter/Gemini only.
- Confirm local `state.vscdb` exists on this machine (path only; tokens not dumped).

**Did not:**

- Capture an authenticated DevTools HAR from `cursor.com/dashboard/spending` against this account.
- Call the RPCs with a live Bearer token (credentials stay in Keychain / IDE DB per QuotAI map).
- Exhaustively verify Enterprise-only shapes beyond published OpenUsage issues.

---

## Practical recommendation for QuotAI PoC

1. Read `cursorAuth/accessToken` (+ refresh) from Cursor `state.vscdb` (or Keychain), refresh via `oauth/token` when needed.
2. `GetCurrentPeriodUsage` → display `planUsage.autoPercentUsed` as Cursor Models; `billingCycleEnd` → days until monthly reset.
3. `GetSandUsageStatus` → display `usagePercent` as Grok Bot; `nextResetTimestampUtc` → days left when present.
4. Optionally fall back to `GET /api/usage-summary` with constructed `WorkosCursorSessionToken` if Connect `planUsage` is empty.
5. Always offer a link to `https://cursor.com/dashboard/spending`.

---

## Sources (index)

1. Cursor help — [Usage and limits](https://cursor.com/help/models-and-usage/usage-limits)  
2. Cursor help — [Grok Bot plans](https://cursor.com/help/grok-bot/plans)  
3. OpenUsage docs — [providers/cursor.md](https://github.com/robinebers/openusage/blob/main/docs/providers/cursor.md) / [openusage.sh](https://openusage.sh/docs/providers/cursor/)  
4. OpenUsage PR — [#1134 Grok Bot + Cursor Models labels](https://github.com/robinebers/openusage/pull/1134) / [commit 65324c6](https://github.com/robinebers/openusage/commit/65324c6c04c169cc8024f9ab47912dc3718b7027)  
5. OpenUsage source — [CursorUsageClient.swift](https://raw.githubusercontent.com/robinebers/openusage/main/Sources/OpenUsage/Providers/Cursor/CursorUsageClient.swift)  
6. OpenTokenUsage — [docs/providers/cursor.md](https://raw.githubusercontent.com/PowerUserZ/OpenTokenUsage/main/docs/providers/cursor.md) (payload + auth keys)  
7. Pulse — [Docs/providers/grok-bot.md](https://raw.githubusercontent.com/qunqin24/Pulse/main/Docs/providers/grok-bot.md)  
8. dmwyatt gist — [Unofficial Cursor dashboard usage API](https://gist.github.com/dmwyatt/1e9359b1862e7cbfe1e754fe4c8db764)  
9. OpenUsage issue — [#829 usage-summary fallback](https://github.com/robinebers/openusage/issues/829)  
10. OpenQuota — [client.rs endpoints](https://github.com/deviffyy/OpenQuota/blob/f9d2884c/src-tauri/src/providers/cursor/client.rs)  
11. Live unauthenticated probes against `api2.cursor.sh` and `cursor.com/api/usage-summary` (2026-09-19)  
12. Local AIMonitor Swift sources (OpenRouter/Gemini only)  
