## Agent skills

### Issue tracker

Issues live as markdown under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Versioning

Bump `MARKETING_VERSION` only when a user-facing change is ready to land. **Always update root `CHANGELOG.md` (and README download / version callouts) in the same commit** — see `.cursor/rules/versioning.mdc`.

Ship tags must be **signed**: `git tag -s vX.Y.Z -m "…"`, then `git verify-tag` before push. Never lightweight or unsigned annotated release tags. Prefer one-shot `-c gpg.format=ssh` / `user.signingkey` over changing global git config unless asked. Do not retag old unsigned releases unless the user explicitly asks.

After bumping version, run `python3 ~/dev/scripts/update-dev-index.py` to refresh `~/dev/INDEX.md`.
