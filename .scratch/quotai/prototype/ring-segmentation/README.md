# Segmented elapsed ring prototype

A throwaway copy of the ring-dimensions prototype, with an interactive segmentation comparison at the top. Open `index.html` in a browser. Toggle segmentation in the preview controls, try the three treatments, and move the elapsed slider. The examples show 30 and 31 days for Cursor, 7 and 3 days for Grok, and 5 hours and 7 days for Codex. Each elapsed segment represents one unit; usage remains continuous. The older dimension controls and A/B switcher are retained below.

The previews are SVG approximations, not native AppKit rendering. No app settings or production behavior are changed.

---

## Original prototype notes

# Ring dimensions — throwaway prototype

2026-11-14. Question: how does doubling only the outer elapsed-time ring affect the existing menu-bar dials?

Run from the repo root:

```sh
python3 .scratch/quotai/prototype/ring-dimensions/run.py
```

This compiles the current AppKit renderer into a temporary executable, exports transparent native PNGs at 1×/2×/4×/8×/16×, and opens the local `index.html?variant=B` directly in your browser. No server is needed. After generation, reopen `index.html` at any time. No dependencies beyond Python 3 and the installed Swift/macOS SDK. `--build-only` regenerates without opening a browser.

- A: current 0.8 pt timeline stroke, radius 9.2 pt, visible diameter 19.2 pt.
- B: 1.6 pt timeline stroke, radius 9.6 pt, visible diameter 20.8 pt.
- Both: usage stroke 3.2 pt, radius 6.65 pt, usage outer diameter 16.5 pt, opening diameter 10.1 pt, air gap 0.55 pt. 22 pt image height.
- B preserves the timeline inner radius of 8.8 pt and grows outward. The horizontal slot grows from 20 to 21.6 pt; text and group spacing stay the same. AppKit measures the native text column width.

The lab offers whole-row zoom, actual-size side-by-side comparisons, an annotated native dial, all dimensions in a table, and a radial section. The bottom switcher and arrow keys alternate A/B; the URL retains the variant and zoom. High-resolution mode redraws through AppKit; pixel mode enlarges the fixed Retina 2× raster.

The baseline renderer is the actual production file, not an SVG reimplementation. B is generated as an ephemeral copy with exactly three metric edits. The source hash and measured image sizes are recorded in assets. Colors use white ink and the app's calibrated over-pace RGB `(1, .55, .05)` with the native opacities. The purple backdrop is approximate; the original screenshot file, wallpaper material and unrounded percentages are unavailable. Sample whole percentages reproduce the supplied labels. Blink is held on. Browser zoom, color profiles and native raster alignment can affect physical appearance.

Status: proposal for review; no design decision approved, no application behavior changed. Scratch-only: no version bump. This directory is already ignored by the repo. Keep it local while reviewing; capture on a throwaway branch when an implementation decision is made, following the prototype skill and repository commit authorization rules.

## Bar proportions — 2026-11-14

The supplied follow-up screenshot shows the 19.2 pt visible dials spanning about 38 Retina pixels inside about 48 pixels of menu-bar content. The reference therefore defaults to 24 pt of bar content plus a 0.5 pt bottom separator. This is a screenshot-derived inference, not a verified live screen measurement: the sandbox has no NSScreen connection and NSStatusBar.system.thickness returns the generic 22 pt. An explicit Bar height field allows matching another display without changing the icon dimensions.

At 24 pt, the 22 pt image has 1 pt of vertical margin on each side. The current circle leaves 2.4 pt above/below; the proposal leaves 1.6 pt. At 4× the bar content is 96 CSS px and circles are 76.8 / 83.2 CSS px; at 8× these all double. The bottom separator scales with them. Measurement annotations and neutral staging padding are outside the purple bar. The 1× comparison uses the same model.

The 16 pt side margins provide a finite context crop and are explicitly not a measurement of OS status-item padding. The real menu bar extends across the display. The blue strip in the actual-size comparison is desktop context outside the bar.

## Code and independent measurement — 2026-11-14

The “Code vs measured rendering” table shows source-derived dimensions, independently measured PNG dimensions, their difference, and the corresponding drawing expression for the selected A/B variant. A separate table shows every extracted metric's exact production declaration and line number, beside the value used by the proposed renderer. `run.py` extracts these declarations from the current source rather than copying a remembered value.

The measurement reads the generated 16× native dial PNG back from disk, scans its horizontal midpoint, detects the four alpha bands, and interpolates half-peak-opacity edges. It receives no source ring dimensions. Diameters, stroke widths, and gaps come from those edge positions; canvas dimensions come from the PNG header. The displayed conservative raster resolution is ±1/16 pt (0.063 pt). Source dimensions remain the geometry contract; anti-aliasing and pixel rounding explain small raster differences. Screenshot readings remain approximate visual cross-checks and are not presented as precise raster measurements. Invisible layout slots and font point sizes have source values, without claiming they can be measured directly from visible ink.

## Linked measurement drawing — 2026-11-14

Each row in “Code vs measured rendering” has a numbered selector. Hovering the row, focusing the selector with Tab, or selecting it highlights that dimension in a companion native-icon drawing. The same number and name appear above the graphic, alongside the code and measured values and a plain-language description. Diameter rows draw a cyan circle and a line across the relevant edge or centerline. Stroke/gap rows highlight only the corresponding radial band. Canvas width/height rows switch to the full three-dial image and mark the complete rectangular canvas, so they cannot be confused with one dial’s diameter or with menu-bar height. The table scrolls independently beside the drawing; narrow layouts stack them. Variant changes retain the selected measurement.

## Circle-to-bar clearance — 2026-11-14

Rows 12 and 13 mark the vertical gaps from the outermost circle edge to the menu-bar top and bottom content edges. Both equal `(barHeight − visibleOuterDiameter) / 2` for the centered icon: 2.4 pt in A and 1.6 pt in B at the screenshot-derived 24 pt bar height. The bottom content edge is the beginning of the 0.5 pt separator; the separator’s outside edge is 2.9 pt / 2.1 pt away from the circle. Changing Bar height recomputes these dimensions and updates the companion drawing.

The companion drawing includes the actual native dial inside a proportional bar, with cyan extension lines and a vertical gap arrow. The table’s raster-derived gap combines the independently measured diameter with the chosen bar height. It is explicitly not presented as an independent live menu-bar measurement. New loads select the top clearance by default.

## Center icon and nested rings — 2026-11-15

The center-icon preview supports a 0–100% opacity slider (50% by default), two-ring and three-ring modes, the A/B geometry controls, and 1× plus the selected zoom. Three rings mean one elapsed ring and two usage rings. The nested usage stroke is half the single-usage stroke, matching `RingIcon`; the icon fits the innermost opening with 0.4 pt of total clearance. The preview uses the supplied OpenAI vector and live SVG, so pixel antialiasing differs from AppKit.

A retains the original pre-change native snapshots. B defaults to the subsequently selected 1.6 / 3.2 / 0.8 / 10 / 21 pt geometry and uses live SVG; its native preset remains the earlier experiment. The launcher preserves historical snapshots instead of regenerating them when source geometry no longer matches.

## Icon and usage-color controls — 2026-11-15

The live center preview switches between the app's Cursor, Grok and OpenAI masks and a Perplexity preview-only icon. Perplexity's SVG path is from Simple Icons (CC0): https://github.com/simple-icons/simple-icons/blob/develop/icons/perplexity.svg. It does not add a provider to the app. Icon gap is a radial inset in points (0.5 pt default, clamped to the available opening); opacity and geometry remain adjustable. The usage-ring color picker and White button control the adjusted preview; the elapsed ring remains white. This candidate uses a 0.5 pt radial center-icon inset, pending running-app verification.

## Pace presets — 2026-11-15

Over, Under and Exhausted set representative usage/elapsed percentages to 91/60, 30/65 and 100/84, with AppKit pace colors converted from calibrated RGB to sRGB (#ff9e08, #55c5ff, #ff5a5e). Example restores the original sample. Presets apply to the adjusted preview and both single and nested center dials; nested preview shows both usage rings in the selected state. The white button still overrides usage color. These are static examples, not evaluations of the user's real corridor settings or blink state.

## Individual center-icon gaps — 2026-11-15

The prototype has separate Cursor, Grok, OpenAI and Perplexity gap inputs. Each starts at 0.5 pt per side and the selected icon uses its own input. Values remain independent for the lifetime of the page, including across variant, preset and ring-mode changes. This is a prototype setting; it does not change app settings or persist across reloads.

## Selected icon gaps — 2026-11-15

The user's screenshot selected Cursor 0.55 pt, Grok 0.6 pt, OpenAI/Codex 0.7 pt and Perplexity 1 pt, at 50% center opacity. The prototype defaults now reflect these values. The first three are candidate app targets; Perplexity remains a preview-only target until its provider exists.
