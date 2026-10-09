# 18: Settings opens on General

**What to build:** Each time the Settings window opens, it shows the General pane, instead of the pane it showed last. Choosing Settings… while the window is already open brings it to the front without switching panes. The stored last pane (`settingsPane` in UserDefaults) is no longer read or written; the leftover value can stay. A conscious departure from Apple's own apps, which reopen on the last pane (decided 2026-10-09).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Open Settings, switch to Shortcuts, close the window, open Settings again: it shows General
- [ ] Same after quitting and relaunching
- [ ] With Settings open on Editor, choosing Settings… again keeps Editor
