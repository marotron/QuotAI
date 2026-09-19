# Scaffold production app shell

Type: task
Status: resolved
Blocked by: 07

## Question

Scaffold the production QuotAI macOS app shell so implementation can start after seams are locked:

- XcodeGen + `MenuBarExtra` (or agreed shell)
- Keychain stub matching the auth decision
- Menu action to open the Cursor Spending URL
- Empty / stubbed quota display wired to presentation model types

This ticket unblocks implementation; it does not deliver the full destination alone. Record what was created and where.

## Answer

**Swift / macOS only** (production). Created:

| Piece | Path |
|-------|------|
| XcodeGen | `project.yml` → `QuotAI.xcodeproj` |
| App (`MenuBarExtra`, LSUIElement) | `QuotAI/QuotAIApp.swift` |
| Core (pace, presentation, Keychain constants) | `QuotAICore/Sources/` |
| Unit tests (5 passing) | `QuotAICore/Tests/` |
| Make targets | `Makefile` (`project`, `test`, `run`) |

Stub meters + **Open Cursor Spending**. Live URLSession + Keychain import/refresh still TODO.

Throwaway API proof remains Python under `.scratch/quotai/poc/` — not production.
