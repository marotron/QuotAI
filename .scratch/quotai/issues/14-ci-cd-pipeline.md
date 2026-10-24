# CI/CD pipeline (PR tests + Release harden)

Type: task
Status: resolved
Blocked by:
GitHub: —

## Question

Add continuous integration for PRs and `main`, and harden the tag Release job so `make test` runs before packaging — documented in-repo for agents.

## Acceptance sketch

- [x] `.github/workflows/ci.yml` — `pull_request` + `push` to `main` → brew XcodeGen → `make test` on `macos-15`
- [x] `.github/workflows/release.yml` — `make test` before `make dmg` on tag `v*`
- [x] `docs/agents/ci-cd.md` + README / `AGENTS.md` pointers
- [x] No SemVer bump (docs/chore)

## Answer

Status: resolved

- CI workflow gates every PR and push to `main` with the same `make test` target used locally.
- Release workflow still creates the GitHub Release only on signed `v*` tag push; it now fails the job if tests fail before DMG / publish.
- Optional Developer ID / notary remain repo secrets (`QUOTAI_SIGN_IDENTITY`, `QUOTAI_NOTARY_PROFILE`); without them, ad-hoc sign (unchanged).
- Full where/when matrix: [docs/agents/ci-cd.md](../../../docs/agents/ci-cd.md).
- Parallel work landed on MailGent `feat/ci-cd-pipeline` (same CI shape; strip → test → dmg).

## Comments

### 2026-10-24

Implemented on `feat/ci-cd-pipeline`. About window (#21) already on `main`; this ticket is CI/CD only.
