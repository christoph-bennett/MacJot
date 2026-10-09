# 18: Settings opens on General

**What to build:** Each time the Settings window opens, it shows the General pane, instead of the pane it showed last. Choosing Settings… while the window is already open brings it to the front without switching panes. The stored last pane (`settingsPane` in UserDefaults) is no longer read or written; the leftover value can stay. A conscious departure from Apple's own apps, which reopen on the last pane (decided 2026-10-09).

**Implementation note:** the window switches back to General when it closes (after it's off screen), not when it opens: a window hidden with the app (e.g. another app's Hide Others) isn't visible either, but it's still open and keeps its pane. Settings has no minimise button and Jot no Hide menu item, as usual for a menu-bar app's Settings.

**Blocked by:** none

**Status:** done

- [x] Open Settings, switch to Shortcuts, close the window, open Settings again: it shows General
- [x] Same after quitting and relaunching
- [x] With Settings open on Editor, choosing Settings… again keeps Editor
