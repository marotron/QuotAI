# Cursor usage CSV fields (research aid only)

**Runtime boundary (updated 2026-11-14):** local Agent Host logs and meter/history remain the primary detector inputs. User-approved RC5 selectively queries Cursor's detailed billing events for unmatched activity. CSV is research evidence only; there is no runtime CSV import. This supersedes the former local-only restriction after live API access was verified.

**Model display:** source string is the local Agent Host `modelId`, with one rewrite: `default` → `auto`. Never upgrade a short local id via CSV timestamp join when the variant is ambiguous.

## Export audit (Nov 2026 sample)

| Column | Useful now? | Note |
| --- | --- | --- |
| **Model** | Yes (reference) | Confirms pool map: `auto` / `composer*` / `cursor-grok*` → Cursor Models; third-party → Other. Often more specific than local (`glm-5p3-flash-high`); keep the local short form when that is all the log provides. |
| **Cost** (`Included` / `Free`) | Maybe later | `Free` rows always have empty tokens. Could mark non-consuming calls if we ever imported CSV. |
| **Token columns** | Maybe later | Size signal only with CSV import; not in Agent Host logs. |
| **Kind** | No | Always `Included` here (plan membership, not discrepancy kind). |
| **Max Mode** | No | Always `No` in this file. |
| **Cloud Agent ID / Automation ID** | No | Always empty — no subagent / parent-mode link. |

## Auto-subagent ≠ Cursor Models reclass

CSV has **no** “invoked under Auto” / parent field. When a Task/subagent runs Claude/GLM/etc., both the local log and CSV name that model explicitly (not `auto`). Do **not** reclassify third-party `modelId`s onto Cursor Models based on belief. Keep `CursorActivityParser.classify` rules.

Local logs also expose unused `actionCase` values (`userMessageAction`, `summarizeAction`, `backgroundTaskCompletionAction`) — richer than this CSV, but YAGNI until needed.

## 14 November 2026 follow-up

The new `usage-events-2026-11-14.csv` sample differs from the earlier audit: 3 rows have Kind `User API Key` (all Gemini 4 Hydrogen), 3,920 have Kind `Included`. The user confirms the Gemini calls were billed directly to Google, outside both Cursor quota pools.

Importantly, the corresponding local runtime records already identify them with `reason: "byok-connect-routed"`. The installed Cursor router emits this when model credentials are present. Preserve that per-turn reason rather than infer external billing from the model name. `runtime: "connect"` alone is not sufficient. No CSV import is needed for this signal.

See [the investigation](cursor-discrepancy-investigation-2026-11-14.md) for counts, replay evidence, plan-specific billing caveats, and the proposed conservative treatment of unresolved activity.
