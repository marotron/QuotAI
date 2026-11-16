# Segmented elapsed ring

**Status: locked for 0.23.0; native appearance approved 2026-11-16, remaining acceptance checks pending.** Decision agreed 2026-11-15. The [locked menu-bar icon prototype](../.scratch/quotai/window-prototypes/locked/segmented-elapsed-2026-11-16/index.html) is the visual reference; select **Wider gaps**. It is an icon study, not a settings-window design.

## Behavior

- Provide an option in **Settings → Display** to enable segmentation of menu-bar elapsed rings. With the option off, elapsed rings remain continuous.
- With the option on, divide the entire elapsed ring into equal segments representing units of the actual quota window: one per day for day-based windows, and one per hour for an hourly window. Apply this to Cursor, Grok, and OpenAI/Codex rings when a valid window is available.
- Examples: a 30- or 31-day Cursor window has 30 or 31 segments; a 7- or 3-day Grok window has 7 or 3; a 5-hour Codex window has 5, and a 7-day window has 7. Use the actual window rather than a fixed provider-specific count.
- Use the prototype's **Wider gaps** treatment for the elapsed track and elapsed progress. The elapsed progress can stop within a segment. The usage ring remains continuous. The existing elapsed direction and other ring presentation remain in effect.
- Candidate implementation 2026-11-16: the option is off by default and appears for ring styles with a separate elapsed ring. Rings · by pace has no separate elapsed ring; bars are unaffected. Whole-day windows allow up to one hour of daylight-saving variation for windows of at least two days; otherwise whole-hour windows are segmented. Non-integral, unavailable, or excessively long windows remain continuous. Gaps follow the prototype formula, capped at 0.65 pt along the centerline and at 30% of each segment pitch. The user approved the native menu-bar appearance on 2026-11-16; settings and remaining provider-state acceptance checks are pending.
- The prototype's other gap treatments and its controls are exploration aids, not additional product settings.

## Acceptance checks — pending

- [ ] Display exposes the option; toggling it changes the menu-bar elapsed rings between continuous and segmented.
- [ ] Verify all example counts above and that a changed window duration changes its segment count.
- [ ] Verify partially elapsed segments, both elapsed track and progress, and continuous usage rings, including supported nested and individual ring styles.
- [ ] Compare the native menu-bar icons against the **Wider gaps** prototype at actual size, including the dense 30- and 31-segment examples.
- [ ] Record implementation and verification evidence here before marking any check complete.

## Verification evidence

2026-11-16: `make test` passed for 0.23.0-rc.1 (build 89). `ElapsedRingSegmentationTests` covers the example duration counts, a daylight-saving adjustment, invalid durations, and gap geometry. This does not establish the on-screen result or live provider wiring; those acceptance checks remain open.

2026-11-16: the user supplied and approved the native menu-bar screenshot for release. The [bar-only crop](screenshots/segmented-elapsed-rings.png) records that appearance; it does not verify every provider window or settings state.
