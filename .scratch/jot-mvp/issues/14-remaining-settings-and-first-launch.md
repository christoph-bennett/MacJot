# 14: Remaining settings and first launch

**What to build:** Settings is completed with: **Launch at login** toggle (default on, takes effect without restart), **font size** for the editor, **relative dates** toggle for the Note List (default on; off shows absolute dates in the system short format, e.g. `08.10.26, 07:15`), and a single **Reset Panel Size & Position** button. On first launch, with no onboarding flow, Jot creates the default Notes Folder, shows a brief hint near the status item listing both hotkeys, and opens a Draft.

**Blocked by:** 04, 05, 06, 07

**Status:** ready-for-agent

- [ ] Launch at login toggle reflects and changes the real login-item state immediately
- [ ] Font size change applies live to the editor and persists
- [ ] Relative dates off → Note List shows system short-format dates; on → "2h", "Mon"
- [ ] Reset Panel Size & Position restores default size, centred on the current screen
- [ ] First launch (no prior preferences): folder created, hint shows both current hotkeys, Draft opens
- [ ] Hint does not appear on later launches
