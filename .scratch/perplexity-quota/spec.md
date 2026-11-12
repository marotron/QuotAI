# Perplexity quota (optional provider)

Status: draft (spec + plan, not approved for implementation)
Type: feature (user-facing, MINOR bump at ship)
Branch when built: `feat/perplexity-quota`

## Summary

Add Perplexity as an optional third provider next to Cursor and Grok Bot. It is off by default. When on, QuotAI reads the Perplexity quota from the rate-limit endpoint and shows it as a row in the menu-bar dropdown. It never appears in the menu-bar icon.

Because the endpoint shows only remaining usage (no reset time, as far as we know), QuotAI learns the reset schedule by observing the quota over time. The learning is deliberately simple and approximate.

## Goals

- Opt-in Perplexity row in the dropdown, listed after Cursor and Grok.
- Sign-in captured once, stored in the Keychain, reused for polls.
- Learn the maximum quota and the reset period from observed readings.
- Show which phase the learning is in, and why it restarted when it does.

## Non-goals

- No menu-bar icon or bar text for Perplexity.
- No macOS notifications for phase changes or restarts. Dropdown status line only.
- No pace corridors or pace alerts for Perplexity in v1. Raw quota numbers only.
- No browser-cookie scraping (Safari or Chrome) in v1.
- No precision guarantees. Minute-level accuracy after learning is good enough.
- No multi-account support.

## Decisions (locked)

| Topic | Decision |
|---|---|
| Visibility | Dropdown row only. Off by default. Settings toggle. |
| Row order | Cursor → Grok Bot → Perplexity |
| Cookie capture | In-app sign-in wizard (embedded web view). Paste fallback in Settings. |
| Cookie storage | Keychain, separate item from Cursor's |
| Display depth | Raw quota numbers only |
| Status notices | Dropdown status line only. No macOS notifications. |
| Learning cadence | Every 4 hours until a period is known |
| Narrow window | Predicted reset ± 10 minutes, on top of current uncertainty |
| Narrow polling | Every minute inside the window |
| Steady polling | Regular refresh setting (once period is known and confirmed) |
| Restart rule | Two misses in a row restart timing learning |
| Learned max | Kept across restarts. Cleared only if readings contradict it. |

## Behavior

### Auth

1. User turns on Perplexity in Settings.
2. Dropdown row shows "Sign in". Settings offers two actions:
   - **Sign in to Perplexity** opens an embedded web view on `https://www.perplexity.ai`.
   - **Paste cookie…** opens a text field (fallback for failed embedded login, such as Google sign-in blocking embedded browsers).
3. After sign-in, the app reads the `perplexity.ai` cookies from the web view's cookie store and saves the cookie header to the Keychain. The user never sees the value.
4. On 401 or 403 from the endpoint, the row shows "Sign in again". Polling stops until a new cookie is saved. No automatic retry loop.

Keychain item:

- Service: `dev.marotron.QuotAI`
- Account: `perplexity-cookie`
- Value: cookie header string for `perplexity.ai`
- Accessibility: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`

### Reading the quota

- Endpoint: `GET https://www.perplexity.ai/rest/rate-limit/all`
- Headers: `Accept: application/json`, `Cookie: <stored cookie header>`
- Timeout: 20 seconds (matches the reference snippet)
- Parse: the remaining value and any limit or reset field (exact shape pending the example payload, see Open questions).

### Learning state (simple)

Stored state (all small, in UserDefaults or a JSON file next to the existing pace history):

- `learnedMax`: highest quota total seen
- `lastResetAt`: time of the most recent detected reset (optional)
- `resetGaps`: last 2 reset-to-reset gaps (optional)
- `missCount`: consecutive misses (0, 1, or 2)

Derived:

- `period`: the most recent gap, once two resets have been seen. Use the median if there are three or more.
- `predictedReset`: `lastResetAt + period`. Absent until a period exists.
- `window`: `predictedReset ± (uncertainty + 10 min)`. Uncertainty is the width of the last reset bracket (or the period's own spread once known).

### Reset detection

- A reset is a jump up in remaining value between two consecutive successful readings.
- The reset time is somewhere in the bracket between those two readings.
- A jump to a value that is not near `learnedMax` is logged as "unexpected level" and not counted as a reset.

### Poll interval

| Phase | Condition | Interval |
|---|---|---|
| Learning | No period yet | Every 4 hours |
| Narrowing | Now is inside `window` | Every 1 minute |
| Steady | Period known, now outside `window` | Regular refresh setting |

Steady uses the regular refresh setting, not 4 hours. The learning phase is the only place the 4-hour cadence is used.

### Misses

A miss is one prediction that the data contradicts. It is one of:

1. **Early or late reset.** A reset bracket falls completely outside `window`.
2. **No reset.** A reading is taken after `window` ends, and the value has not jumped.

Not a miss:

- No data (sleep, network error). Record as unknown. Do not count it.
- A reading inside a reset bracket that the next reading has not confirmed. Wait for the next reading.

Two misses in a row (`missCount == 2`) restart the timing model:

- Clear `lastResetAt`, `resetGaps`, `window`, and `missCount`.
- Keep `learnedMax`.
- Go back to the learning phase (4-hour polling).
- Set the status line to "Restarted · <reason>", e.g. "Restarted · reset came 2h early".

A hit (reset bracket overlaps `window`) resets `missCount` to 0.

### Status line (dropdown row)

One line under the Perplexity row, examples:

- "Learning · 1 of 2 resets"
- "Narrowing · reset expected 14:20 ±10 min"
- "Steady · next reset Mon 09:00"
- "Restarted · reset came 2h early"
- "Sign in again"

No macOS notifications.

## Plan

Swift stack pin (from `project.yml`):

- Swift `5.10`, macOS deployment target `14.0`
- Pure logic in `QuotAICore` (framework target, unit tests in `QuotAICoreTests`)
- UI and Keychain/WebKit adapters in the `QuotAI` app target
- SwiftUI for Settings and dropdown row, matching existing panel code
- `WKWebView` for sign-in (available on macOS 14)

### Gates

- **TDD:** proposed seams listed below. Tests are written only after the user confirms the seams.
- **KISS/DRY/SOLID/YAGNI:** pure functions for parse, reset detection, interval choice, and miss detection. No protocol for every type. One Keychain adapter, one fetch client.
- **Visual features:** the Perplexity dropdown row and Settings controls follow the HTML proto process. Build an HTML proto in `.scratch/perplexity-quota/` and get it approved before SwiftUI. Reuse existing panel components where the job matches.

### Proposed test seams (confirm before writing tests)

1. `PerplexityQuotaParser.parse(data) → Quota` (pure). Needs the example payload.
2. `ResetDetector.detect(readings) → [ResetBracket]` (pure).
3. `PerplexityLearner.next(state, reading, now) → (state, pollInterval, statusText)` (pure). Covers learning, narrowing, steady, misses, and restart.
4. `CookieStore` protocol with Keychain and in-memory implementations (for tests).
5. `PerplexityFetcher` takes a `URLSession`-like function (for tests with canned responses).

### Steps (vertical slices, after payload is pasted)

1. **Payload confirmation.** Read the example JSON. Confirm the remaining-value field, limit field (if any), and any reset field. Update the Parser section and the learning rules if an explicit reset time exists.
2. **Parser (QuotAICore).** Red → green on the sample payload. Includes auth-failure mapping for 401 and 403.
3. **Reset detection and learner (QuotAICore).** Red → green on synthetic series: learning, narrowing hit, early miss, no-reset miss, two-in-a-row restart, unknown samples ignored.
4. **Cookie store (QuotAI).** Keychain item read and write. Manual check in the running app.
5. **Fetcher (QuotAI).** Uses the stored cookie. Maps errors to "Sign in again" or "Unavailable".
6. **Sign-in and paste fallback (QuotAI).** `WKWebView` sheet, cookie harvest, Settings paste field. Manual check: sign in, cookie saved, endpoint returns JSON.
7. **Settings toggle and dropdown row (QuotAI).** Build the HTML proto first, get approval, then SwiftUI. Status line from the learner.
8. **Wire into the refresh loop.** Poll interval from the learner. Pause when off or signed out.
9. **Ship.** MINOR bump (current `0.18.2` → `0.19.0`), `CHANGELOG.md` section in the same commit, README callout if it names the version, branch `feat/perplexity-quota`, signed tag `git tag -s v0.19.0 -m "0.19.0"`, `git verify-tag` before push. Propose the commit message and wait for confirmation before committing.

### Verification

- `make test` (or the existing test scheme) passes.
- Manual: sign in, see a real quota row, confirm the first learning poll and a 4-hour cadence in logs.
- Manual: a real reset is observed and recorded. The status line changes from "Learning" as expected.

## Open questions

1. **Payload shape.** Does the response include a limit, a reset time, or only a remaining count? This decides whether learning is needed at all. Pending the example JSON.
2. **Cookie name.** Which `perplexity.ai` cookie is the session credential? Needed only for validation, not for storage (we store the full header).
3. **Google sign-in in embedded web view.** Confirm whether it's blocked. If it is, the paste fallback is the only path for Google accounts.
4. **Rate limits.** Does Perplexity throttle frequent polling? The narrow phase is about 1 request per minute for up to about 20 minutes per reset.
5. **Plan changes.** A jump to a new maximum is logged as "unexpected level" and does not count as a reset. Confirm that is acceptable.

## Comments

### 2026-11-12

- Spec drafted from the design conversation. Decisions above are the agreed set.
- Next step: paste the example response JSON so Open question 1 can be closed and the Parser slice can start.
