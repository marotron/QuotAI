# Settings: Account and refresh grouping

Research date: 2026-11-14. This is a recommendation, not an implemented or verified product decision. It examines the current working tree, including unfinished automatic-refresh changes.

## Findings

- The Settings window is fixed at 460 × 620 points and has five tabs: Display, Account, Alerts, Email, and Menu pins. Its grouped forms can contain more content than the available height. [SettingsView](../../../QuotAI/SettingsView.swift#L167)
- Account currently interleaves three different jobs: refreshing and its current status, configuring automatic refresh, and managing Cursor-specific authentication and local activity diagnostics. Refresh controls precede the Cursor account controls, which are at the bottom. [SettingsView](../../../QuotAI/SettingsView.swift#L249), [Cursor activity and authentication](../../../QuotAI/SettingsView.swift#L380)
- The working tree adds wake, quiet-hours and two high-usage rules to Account; dynamic scheduling adds more rows when selected. The automatic-refresh specification identifies this work as an unshipped candidate and its running-app acceptance as incomplete. [SettingsView](../../../QuotAI/SettingsView.swift#L283), [automatic refresh contract](../../../docs/automatic-refresh.md)
- The Cursor activity controls govern local log reading, data retention and opt-in discrepancy notifications, while Alerts configures separate pace alerts and their delivery. Discrepancy delivery is independently specified. [SettingsView](../../../QuotAI/SettingsView.swift#L380), [Alerts](../../../QuotAI/SettingsView.swift#L417), [discrepancy contract](../../../docs/cursor-discrepancies.md#L76)
- Apple's macOS guidance describes settings panes as groups of related settings, advises keeping the navigation stable, and suggests minimizing settings and exposing task-specific options in context. This supports a coherent refresh pane and retaining the existing menu shortcuts, but does not prescribe a particular split for QuotAI. [Apple Human Interface Guidelines: Settings](https://developer.apple.com/design/human-interface-guidelines/settings)

## Recommendation

Add a **Refresh** tab alongside **Account**. Put refresh status, manual refresh actions, refresh rate, Dynamic schedule, wake, quiet hours and high-usage rules together on Refresh. Put the Dynamic editor immediately after the rate selector so the schedule is easy to find and understand; the remaining automatic policies follow. Keep status and errors visible where a user can retry; an authentication-specific error should also be visible next to re-authentication on Account. Do not change stored settings or scheduling behavior.

Keep **Account** for Cursor re-authentication, token entry, spending link and **Cursor activity** diagnostics. Put account recovery before the activity section. Activity detection is not authentication, but it is specific to the connected Cursor account and has only two related switches, including a privacy-sensitive local-log setting; a separate tab would be disproportionate. Keep its notification switch with detection because it depends on that feature, rather than mixing it into the pace-specific Alerts tab.

The new Refresh tab will still be tall with Dynamic mode and optional rules enabled; a tab split alone will not remove scrolling. Keep related controls adjacent, use concise explanatory copy without discarding important quiet-hours exceptions, and check the tab bar and expanded content in the actual 460-point-wide window before selecting final sizing or introducing another navigation pattern. The present analysis has not measured the running UI, and no usability test is claimed.

If implemented, update the automatic-refresh contract's current Settings → Account location, record the decision and verification, and verify persistence, status/error visibility, manual actions and expanded layouts. [Current contract](../../../docs/automatic-refresh.md#quiet-hours)
