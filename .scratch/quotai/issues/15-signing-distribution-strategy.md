# App Store vs personal signing / distribution

Type: grilling
Status: resolved
Blocked by:
GitHub: [#10](https://github.com/marotron/QuotAI/issues/10)

## Question

Decide how QuotAI is signed and distributed beyond ad-hoc DMG releases (Developer ID / notarization / App Store / Homebrew / website / updates).

## Answer

Status: resolved (2026-10-24 grill)

### Near-term

- Channel: **GitHub Releases** (unchanged).
- Signing / notarization: **deferred** — keep ad-hoc DMGs until Apple Developer Program enroll; optional `QUOTAI_SIGN_IDENTITY` / `QUOTAI_NOTARY_PROFILE` stay unused until then.
- Updates: **manual** download from Releases; revisit Sparkle vs Homebrew only when “eventually” is scheduled.

### Eventual (fog until scheduled)

- Preferred first surface: **dedicated website** (landing page → latest GitHub Release DMG; may change later).
- Homebrew cask and Mac App Store stay on the table.
- Open a separate website ticket only when that work is scheduled (do not pre-create).

### Explicitly not now

- Enroll, notarization pipeline, CI signing secrets wiring as a project.
- Sparkle, Homebrew, App Store, or website build.

### Related follow-up

Install / Gatekeeper packaging polish → [issues/16-pretty-dmg-install-ux.md](16-pretty-dmg-install-ux.md).

## Comments

### 2026-10-24

Grilling rounds locked Q1–Q10. GitHub #10 closed with this strategy; implementation of pretty DMG + docs is ticket 16.
