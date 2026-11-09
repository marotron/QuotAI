# Cursor usage CSV fields (research aid only)

**Standing rule:** QuotAI runtime uses the **local Cursor Agent Host log** (and meter snapshots / pace history) only. No CSV import. This note is for reverse-engineering whether a billing/label signal already exists (or can be derived) in the local log.

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
