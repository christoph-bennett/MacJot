# 13: Hotkey settings

**What to build:** Settings lets the user record a new Capture Hotkey and Search Hotkey. A change re-registers the global hotkey immediately, without restart, and persists across relaunch. If a combination can't be registered (taken by the system or another app) or both hotkeys are set to the same combination, the user is told in Settings and the previous hotkey stays active. Defaults remain `⌃⌥N` and `⌃⌥F`, with a way to restore them.

**Blocked by:** 04, 06

**Status:** ready-for-agent

- [ ] Each hotkey has a recorder control showing the current combination
- [ ] A newly recorded combination works immediately from any app; the old one stops working
- [ ] Unavailable combination → message shown, previous hotkey still active
- [ ] Same combination for both → rejected with a message
- [ ] Restore defaults resets both to `⌃⌥N` / `⌃⌥F`
- [ ] Choices persist across relaunch
