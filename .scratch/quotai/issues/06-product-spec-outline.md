# Product spec outline

Type: grilling
Status: resolved
Blocked by: 01, 04, 05

## Question

What lands in the written product docs before any production QuotAI code?

Decide location and outline for `pr.md` / `tech-specs.md` (vault `04-ideas/05-quotai/` and/or QuotAI `docs/`), incorporating:

- Locked meters and burn-rate wording
- Auth / Keychain story
- PoC learnings (what worked, what is flaky)
- Explicit non-goals already on the map

Why it matters: production scaffolding and TDD seams must follow a written boundary, not chat memory.

## Answer

**Location:** QuotAI repo only — [`docs/pr.md`](../../docs/pr.md) (product) and [`docs/tech-specs.md`](../../docs/tech-specs.md) (tech + seams). Vault `04-ideas/05-quotai/idea-draft.md` stays a pointer / one-liner, not a second spec.

**Outline locked as written in those files:** meters, auth, pace, non-goals, PoC learnings pointer, fetch + TDD seams.

Resolved under “finish planning and progress to build” after PoC success.
