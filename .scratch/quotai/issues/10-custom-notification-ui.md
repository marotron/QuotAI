# Custom notification UI

Type: task
Status: open
Blocked by:
Target: next version (after current compact system banners)
GitHub: https://github.com/marotron/QuotAI/issues/8

## Question

Replace (or optionally override) stock `UNUserNotification` banners with a **Notification Content Extension** so pace alerts can:

- Top-align the QuotAI app icon (system banners always center it)
- Show agent marks inline (Cursor / Other / Grok) instead of short text labels only
- Keep a compact used / elapsed layout without wrapping into a tall banner

## Context

- **Now (ship first):** `AlertMessageBuilder` compact plain-text subject/body (`Cursor · Grok over`, `▲ Cursor 74% / 66%`). System icon alignment stays centered — no UserNotifications API for top-align.
- **Next version:** custom notification content extension (AppKit/SwiftUI) with QuotAI layout control; still deliver via UserNotifications, extension owns the banner chrome.

## Acceptance sketch

- [ ] Notification Content Extension target in the XcodeGen project
- [ ] Banner layout: app icon top-aligned; one row per alerting meter with agent icon + pace mark + used/elapsed
- [ ] Falls back to compact plain-text body if the extension is unavailable
- [ ] Settings “Send test notification” exercises the custom layout
- [ ] Unit-testable payload mapping stays in `QuotAICore` (extension is a thin view)

## Comments

### 2026-10-09

User accepted compact system banners for now; asked to schedule custom notifications for the next version.

### 2026-10-09 (later)

Mirrored to GitHub [#8](https://github.com/marotron/QuotAI/issues/8).
