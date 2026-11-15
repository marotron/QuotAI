# Segmented elapsed ring

**Status: locked target, pending implementation and verification.** Decision agreed 2026-11-15. The [menu-bar icon prototype](../.scratch/quotai/prototype/ring-segmentation/index.html) is the visual reference; select **Wider gaps**. It is an icon study, not a settings-window design.

## Behavior

- Provide an option in **Settings → Display** to enable segmentation of menu-bar elapsed rings. With the option off, elapsed rings remain continuous.
- With the option on, divide the entire elapsed ring into equal segments representing units of the actual quota window: one per day for day-based windows, and one per hour for an hourly window. Apply this to Cursor, Grok, and OpenAI/Codex rings when a valid window is available.
- Examples: a 30- or 31-day Cursor window has 30 or 31 segments; a 7- or 3-day Grok window has 7 or 3; a 5-hour Codex window has 5, and a 7-day window has 7. Use the actual window rather than a fixed provider-specific count.
- Use the prototype's **Wider gaps** treatment for the elapsed track and elapsed progress. The elapsed progress can stop within a segment. The usage ring remains continuous. The existing elapsed direction and other ring presentation remain in effect.
- The prototype's other gap treatments and its controls are exploration aids, not additional product settings. The exact Display layout, initial setting state, treatment of non-integral or otherwise unsupported durations, and precise native gap dimensions have not yet been agreed.

## Acceptance checks — pending

- [ ] Display exposes the option; toggling it changes the menu-bar elapsed rings between continuous and segmented.
- [ ] Verify all example counts above and that a changed window duration changes its segment count.
- [ ] Verify partially elapsed segments, both elapsed track and progress, and continuous usage rings, including supported nested and individual ring styles.
- [ ] Compare the native menu-bar icons against the **Wider gaps** prototype at actual size, including the dense 30- and 31-segment examples.
- [ ] Record implementation and verification evidence here before marking any check complete.
