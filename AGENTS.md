## Agent skills

### Issue tracker

Issues live as markdown under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.
When recording a feature proposal, check existing GitHub issues, including closed issues, for duplicates and related work; link relevant issues and avoid creating duplicates.

### CI/CD

PR and `main` run `make test`; tag `v*` runs test → DMG → GitHub Release. See `docs/agents/ci-cd.md`.

### Application specifications

`docs/pr.md` is the application-wide product contract; `docs/tech-specs.md` records architecture and technical boundaries. Detailed behavior contracts (including `docs/cursor-discrepancies.md`) are linked from both.

When behavior changes, update the relevant specifications in the same change set. Record agreed decisions and dates; distinguish locked targets pending implementation from behavior that is implemented and verified. Keep acceptance checks with the detailed contract and update its status only with verification evidence. Research and historical tickets support the specs rather than override them; record any change to a locked requirement explicitly.

### Versioning

Use the shared RC-first workflow at `~/.codex/skills/release-versioning/SKILL.md` and the QuotAI mapping in `.cursor/rules/versioning.mdc`. Open `X.Y.Z-rc.1` when product work starts; each candidate product/test/Unreleased revision bumps RC and build together. Apple marketing version stays numeric; About/panel show the RC label. Keep notes under Unreleased and public README downloads on the shipped version. On authorized ship, clear candidate to 0, increment build, promote dated notes and update the full relevant README.

Ship tags must be **signed**: `git tag -s vX.Y.Z -m "…"`, then `git verify-tag` before push. Never lightweight or unsigned annotated release tags. Prefer one-shot `-c gpg.format=ssh` / `user.signingkey` over changing global git config unless asked. Do not retag old unsigned releases unless the user explicitly asks.

After bumping version, run `python3 ~/dev/scripts/update-dev-index.py` to refresh `~/dev/INDEX.md`.

