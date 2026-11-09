# Menu-bar panel top-strip troubleshooting log

## Purpose

This is the working log for the `MenuBarExtra(style: .window)` discrepancy-panel
glitch:

`advanced hidden → advanced shown → dropped-top frame / desktop strip → advanced hidden`

The panel should resize from its top edge. The observed failure is that a height
shrink preserves `origin.y`, temporarily lowering `maxY` and exposing the
desktop below the menu bar.

## Mandatory workflow

Before trying a new fix:

1. Read this file from top to bottom.
2. Search the **Do not retry** column and the **Current state** section.
3. Choose a genuinely new mechanism, or explain why an existing mechanism is
   being revisited because new evidence changes its diagnosis.
4. Add a new numbered entry before implementation with status `In progress`.
5. After testing, update the entry with evidence, outcome, and files changed.

Do not retry a solution marked `Failed`, `Crash`, or `Insufficient`. A build
passing is not visual confirmation; mark a solution `Awaiting user visual test`
until the show → hide transition has been tested in the running app.

## Navigation

- [Current state](#current-state)
- [Failure model](#failure-model)
- [Attempted solutions](#attempted-solutions)
- [Evidence files](#evidence-files)
- [Next-solution checklist](#next-solution-checklist)

## Current state

**Latest implementation:** entry 11, fixed-size Advanced popover.

**Latest verification:** `make test` passed and the edited files have no
linter errors.

**Visual status:** entry 11 stops the top-strip glitch. The Advanced popover
opens downward (`arrowEdge: .bottom`); keep iterating on presentation polish
if needed, but do not reopen the failed resize/swizzle paths.

**Relevant files:**

- `QuotAI/MenuBarWindowPanel.swift` — installs the macOS 26 native modifier.
- `QuotAI/PaceHistoryChart.swift` — owns the Advanced discrepancy UI.
- `project.yml` — deployment target is macOS 14.0; `windowResizeAnchor(.top)`
  is therefore availability-gated for macOS 26 and newer.

## Failure model

The screenshots and recordings showed the top edge dropping by approximately
65 px during the transition, then snapping back. The bad frame is presented by
the window server before a post-frame observer can correct it.

The important distinction is:

- **Post-frame mechanisms** can correct the final frame but cannot guarantee
  that the intermediate frame was never displayed.
- **Pre-frame mechanisms** must intercept the setter that publishes the new
  window geometry, without changing the private SwiftUI window object's `isa`.

## Attempted solutions

### 1. Stop or remove SwiftUI height animation

**Mechanism:** Remove `withAnimation`, use `Transaction.disablesAnimations`,
`.animation(nil, value: advancedOpen)`, and isolate the Charts layout with
`.geometryGroup()` / a nil transaction.

**Result:** `Insufficient`. The transition still produced the dropped-top
  frame. This changes SwiftUI layout animation but does not control the
  `MenuBarExtra` window's AppKit frame-origin policy.

**Do not retry:** Do not use animation removal alone as the fix. It can remain
as a supporting measure, but it is not a top-edge anchor.

**Related files:** `QuotAI/PaceHistoryChart.swift`.

### 2. Frame KVO with `NSWindow.didResizeNotification`

**Mechanism:** Observe the live panel's `frame`, compare old and new height,
then call `setFrame(..., display: false, animate: false)` to restore `maxY`.

**Result:** `Failed`. The observer runs after AppKit has already submitted the
short rectangle; the recording still showed one bad frame before the correction.

**Do not retry:** Do not use frame KVO or `didResizeNotification` as the primary
glitch fix. It is acceptable only as diagnostics or a non-critical fallback
after a pre-frame solution is established.

**Evidence:** `.scratch/quotai/vid-frames/hide-contact.png`,
`.scratch/quotai/vid-frames/hide2-f030.png`.

### 3. Freeze screen updates around the SwiftUI state change

**Mechanism:** Use `disableScreenUpdatesUntilFlush`, `NSDisableScreenUpdates`,
`NSEnableScreenUpdates`, `layoutSubtreeIfNeeded`, and a corrective `setFrame`
before flushing.

**Result:** `Failed`. The hide transition still showed the same top-strip
glitch. The state-driven size commit did not remain inside the screen-update
freeze in the required way.

**Do not retry:** Do not return to screen-update freezing as the sole fix. It
also involved deprecated/global display-update behavior in an earlier variant.

**Related files:** historical versions of
`QuotAI/MenuBarPanelTopPin.swift`.

### 4. Set `NSWindow.animationBehavior = .none`

**Mechanism:** Disable the panel window's AppKit animation behavior while the
top-pin view is attached, restoring the previous value when detached.

**Result:** `Insufficient`. Apple documentation indicates this controls
window order-in/order-out behavior, not the content-driven resize frame path.
The top-strip symptom persisted.

**Do not retry:** Do not treat `animationBehavior = .none` as a resize-anchor
API.

### 5. Dynamic subclass of the private MenuBarExtra window

**Mechanism:** Allocate a runtime subclass, override
`setFrame:display:animate:` and related methods, then apply it with
`object_setClass`.

**Result:** `Crash`. Opening the menu-bar icon caused a Swift runtime cast
failure (`swift_dynamicCastObjCClassUnconditionalImpl`) because AppKit/Swift
code expected its private window class and the dynamically allocated subclass
was not registered as a Swift class.

**Do not retry:** Never use `objc_allocateClassPair` plus `object_setClass` for
this panel.

### 6. Dynamic subclass with additional exception/display-cycle handling

**Mechanism:** Retain the dynamic subclass approach while adding re-entrancy
guards and handling nested AppKit/display-cycle calls.

**Result:** `Crash`. The cast crash changed into an AppKit exception during the
Core Animation display-cycle observer (`-[NSApplication _crashOnException:]`).

**Do not retry:** This is the same unsafe mechanism, not a separate viable
path. Do not attempt to make dynamic subclassing safer with more guards.

### 7. Method swizzle of only `setFrame:display:animate:`

**Mechanism:** Exchange the implementation on the private window's concrete
runtime class without changing `isa`; pin `origin.y` whenever height changes.

**Result:** `Insufficient`. Crashes stopped, but the top-strip glitch persisted,
indicating that this was not the only geometry path used by the live panel.

**Do not retry:** Do not reintroduce the single-setter implementation as-is.
Any revision must cover the missing setter path and preserve class-local
swizzle isolation.

### 8. Native SwiftUI `.windowResizeAnchor(.top)`

**Mechanism:** Apply `.windowResizeAnchor(.top)` when available.

**Result:** `Insufficient for the supported range`. The API is available on
macOS 26 and newer, while the app deploys to macOS 14. It cannot solve the
reported behavior on macOS 14–25. It remains enabled as a native improvement
on macOS 26+.

**Do not retry:** Do not raise the deployment target solely to use this API
unless the product requirement changes.

### 9. Class-local multi-setter method swizzle — current

**Status:** `Insufficient`.

**Mechanism:** Swizzle the live private window class without `object_setClass`
and without mutating inherited `NSWindow` aliases. Cover:

- `setFrame:display:animate:`
- `setFrame:display:`
- `setContentSize:`
- `setFrameOrigin:`
- `setFrameTopLeftPoint:`

The frame setters pin height changes to the captured `maxY`. The content-size
path converts the target content size to an outer frame and submits the pinned
frame once, avoiding the original bad `setContentSize` publication. Nested
calls pass through an explicit re-entrancy guard.

**Why this is new:** Entry 7 covered only one setter. Entry 9 also fixes the
class-local aliasing problem and covers content-size/origin-only paths.

**Verification completed:** Build, tests, and linter pass.

**Visual result:** The menu-bar click crash did not recur, but the top-strip
glitch still appeared on the reported `show → glitch → hide` transition.
This establishes that the active `MenuBarExtra` resize path is not reliably
intercepted by the public Objective-C geometry setters.

**Do not retry:** Do not add more guessed `NSWindow` setter swizzles. Capture
an exact AppKit call path first if this approach is ever reconsidered.

### 10. Stable advanced-layout slot

**Status:** `Insufficient`.

**Mechanism:** Keep the advanced legend row and collapsed discrepancy strip in
the SwiftUI layout whenever discrepancy data exists. When Advanced is closed,
hide the slot visually and disable its interaction instead of removing it.
The `MenuBarExtra` panel consequently retains the same height through the
Advanced show → hide transition, so AppKit has no frame shrink to place from
the bottom edge.

**Why this is new:** Entries 1–9 attempt to control the private
`MenuBarExtra` window's changing frame. This avoids that unsupported resize
operation entirely. It deliberately trades the compact closed panel height for
a stable panel height while keeping the existing Advanced interaction.

**Implementation:** Removed the private-window swizzle and its hosting view.
The macOS 26 native `.windowResizeAnchor(.top)` remains enabled where
available, but macOS 14–25 now use only the stable SwiftUI layout.

**Verification completed:** `make test` passed.

**Files:** `QuotAI/PaceHistoryChart.swift`,
`QuotAI/MenuBarWindowPanel.swift`.

**Visual result:** The hidden slot leaves objectionable permanent blank space
in the chart well. It only reserves the collapsed Advanced content; expanding
the event list still changes the panel height and reproduces the top-strip
glitch.

**Do not retry:** Do not reserve advanced content in the main panel unless the
entire maximum expanded height is reserved. That larger permanent gap is not
an acceptable closed-state design.

### 11. Content-sized Advanced popover — current

**Status:** `Locked in — shipping in 0.18.2`.

**Mechanism:** Restore the compact chart well and present the Advanced
discrepancy controls in a separate SwiftUI popover attached to the ellipsis
button. The popover keeps a fixed chart-matched width and hugs its content
height, so collapse/expand of the event list resizes only the popover. The
`MenuBarExtra` panel's layout and frame remain unchanged. Do not keep a
compile-time `windowResizeAnchor(.top)` call gated only with
`#available(macOS 26.0, *)` — CI’s Xcode 16.4 / macOS 15 SDK lacks that API
and the availability check does not skip the compile error.

**Why this is new:** Entries 1–9 modify or intercept the main panel resize,
and entry 10 reserves changing content inside the main panel. Entry 11 removes
Advanced content from the main panel's layout entirely without private AppKit
hooks.

**Expected tradeoff:** Advanced details appear in an attached popover rather
than inline below the chart.

**Verification completed:** `make test` passed and the edited file has no
linter errors.

**Visual result:** The top-strip glitch is gone. The first presentation used
`arrowEdge: .top` and opened upward over the chart; switched to
`arrowEdge: .bottom` so the popover opens downward. A hard-coded popover
height of 200 left empty chrome when the list was collapsed; removed that
fixed height (and the filler `Spacer`) so the popover hugs content.

**Files:** `QuotAI/PaceHistoryChart.swift`.

## Evidence files

- `.scratch/quotai/vid-frames/recording.mov`
- `.scratch/quotai/vid-frames/adv-top-contact.png`
- `.scratch/quotai/vid-frames/hide-contact.png`
- `.scratch/quotai/vid-frames/hide2-f030.png`
- `.scratch/quotai/vid-frames/hide2-f031.png`
- User screenshots in the Cursor session showed
  `show → glitch → hide`.
- User screenshots from 2026-11-08 20:35 and 20:37 showed entry 10's permanent
  closed-state gap and the expanded event list that still triggered the glitch.

## Next-solution checklist

Before changing code again:

- [ ] Read this log.
- [ ] Record the new hypothesis and why entries 1–9 do not already test it.
- [ ] Prefer observing which setter actually fires before adding another hook.
- [ ] Do not use dynamic `isa` mutation.
- [ ] Do not use post-frame KVO as the primary correction.
- [ ] Build and run tests after the change.
- [ ] Update the relevant entry with the user's visual result.
