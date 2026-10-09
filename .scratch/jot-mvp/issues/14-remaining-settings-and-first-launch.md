# 14: Remaining settings and first launch

**What to build:** Settings is completed with: **Launch at login** toggle (default on, takes effect without restart), **font size** for the editor, **relative dates** toggle for the Note List (default on; off shows absolute dates in the system short format, e.g. `08.10.26, 07:15`), a single **Reset Panel Size & Position** button, and an **Ask before moving notes to the Trash** toggle (default on; the confirmation itself exists since ticket 05). Settings panes (ticket 15): launch at login, ask before Trash and reset panel go to **General**; font size and relative dates start the **Editor** pane. Line numbers moved to ticket 16. On first launch, with no onboarding flow, Jot creates the default Notes Folder, shows a brief hint near the status item listing both hotkeys, and opens a Draft.

**Launch at login** (after looking at sindresorhus/LaunchAtLogin-Modern, MIT; our own code, no dependency): the toggle reads `SMAppService.mainApp.status` each time, never a stored copy, so removing Jot under System Settings > General > Login Items shows up in Settings. Turning it on unregisters first if already enabled, then registers, which repairs a stale registration (e.g. after `scripts/install.sh` replaced the bundle with a newly ad-hoc-signed build). A failed change is logged and the toggle shows the real state again. Unlike the package, `.requiresApproval` (switched off under "Allow in the Background") is shown as such, with a button that calls `SMAppService.openSystemSettingsLoginItems()`. The first-run default-on registration stays behind its flag, so Jot never re-enables it after the user turned it off. Note: the Mac App Store rejects launch at login enabled by default; fine for direct distribution, revisit if Jot ever goes there. In Settings > General, labelled "Open at Login:".

**Blocked by:** 04, 05, 06, 07, 15

**Status:** ready-for-agent

- [ ] Launch at login toggle reflects and changes the real login-item state immediately
- [ ] Font size change applies live to the editor and persists
- [ ] Relative dates off → Note List shows system short-format dates; on → "2h", "Mon"
- [ ] Reset Panel Size & Position restores default size, centred on the current screen
- [ ] With "Ask before moving notes to the Trash" off, deleting from the Note List, context menu or `⋯` trashes immediately; on (default) shows the confirmation
- [ ] First launch (no prior preferences): folder created, hint shows both current hotkeys, Draft opens
- [ ] Hint does not appear on later launches
