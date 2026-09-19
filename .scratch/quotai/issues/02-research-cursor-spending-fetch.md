# How Cursor Spending data is fetched today

Type: research
Status: resolved
Blocked by:

## Question

Document how Cursor Spending quota data can be fetched today (unofficial / private dashboard path is acceptable):

- Endpoints or RPCs (e.g. OpenUsage, dashboard GraphQL/REST) that expose usage for **Cursor Models** (monthly) and **Grok Bot** (weekly)
- Auth / session mechanism required
- Response fields that map to `% used` and reset time / days left
- Known failure modes (Cloudflare, expired session, missing fields, rate limits)

Prefer primary sources: network traces against cursor.com spending pages, Cursor client/source if available, public GitHub/issue discussions that cite concrete URLs or payloads. Not xAI console APIs.

Write findings to `.scratch/quotai/research/cursor-spending-fetch.md` with citations, then resolve this ticket with a short answer + link.

## Answer

Unofficial path is solid enough for a PoC: Connect RPC `GetCurrentPeriodUsage` on `api2.cursor.sh` (Bearer from Cursor `state.vscdb`) exposes Cursor Models as `planUsage.autoPercentUsed` with monthly reset via `billingCycleEnd`; Grok Bot is a separate weekly meter via `GetSandUsageStatus` (or REST twin `POST /api/dashboard/get-sand-usage-status`) using `usagePercent` + optional `nextResetTimestampUtc`. Cookie REST fallbacks (`/api/usage-summary`) help Enterprise/empty `planUsage`. Failures: 401 not logged in, missing Grok fields/eligibility gates, inventing reset from start+7d is wrong.

Full write-up: [research/cursor-spending-fetch.md](../research/cursor-spending-fetch.md)
