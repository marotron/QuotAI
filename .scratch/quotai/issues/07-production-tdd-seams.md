# Production seams for TDD

Type: grilling
Status: resolved
Blocked by: 06

## Question

Agree the test seams before any production test is written:

- Quota response parsing (pure)
- Burn-rate estimate (pure)
- Menu presentation model (pure or lightly stubbed)
- What stays untested at the network/Keychain boundary in v1

Why it matters: scaffold and first production tests should not invent seams after the fact. Consult `/tdd` and `/kiss-dry-solid-yagni`.

## Answer

**Test in v1:**
1. Quota response parsing (pure) — Connect JSON → domain meters / Grok unavailable
2. Burn-rate / pace (pure) — locked formula in `PaceCalculator`
3. Menu presentation model (pure) — meters + bar mode → titles / row models

**Do not unit-test in v1:** URLSession, Keychain, SQLite import (manual / PoC coverage only).

Core types live in `QuotAICore`; app target wires adapters. See [`docs/tech-specs.md`](../../docs/tech-specs.md).
