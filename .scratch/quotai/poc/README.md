# QuotAI throwaway PoC

**Question:** Can QuotAI read live Cursor Models + Grok Bot meters via Connect using Cursor Desktop tokens?

**Run (one command):**

```bash
python3 .scratch/quotai/poc/fetch_meters.py
```

Reads `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`, calls `GetCurrentPeriodUsage` + `GetSandUsageStatus`, prints JSON including pace labels. Does **not** write Keychain (production path); import-only for the PoC.

**PROTOTYPE — not production.** The real QuotAI app is **Swift / macOS** (`QuotAI/`, `QuotAICore/`). Delete or ignore this Python proof after learnings land on the ticket / `docs/pr.md`.
