# 13: Hotkey settings

**What to build:** Settings lets the user record a new Capture Hotkey and Search Hotkey. A change re-registers the global hotkey immediately, without restart, and persists across relaunch. If a combination can't be registered (taken by the system or another app) or both hotkeys are set to the same combination, the user is told in Settings and the previous hotkey stays active. Defaults remain `⌃⌥N` and `⌃⌥F`, with a way to restore them.

**How** (ADR 0005, after looking at sindresorhus/KeyboardShortcuts with the user): use the package as a SwiftPM dependency; it replaces `GlobalHotkey.swift`. `KeyboardShortcuts.Name`s for capture and search with `initial:` ⌃⌥N / ⌃⌥F; `KeyboardShortcuts.Recorder` rows in Settings > Shortcuts (ticket 15's read-only rows, label column "Capture:" / "Search:"); `onKeyDown` handlers in `AppDelegate`; Restore Defaults calls `reset`. "Both the same" goes through the recorder's custom shortcut validation, with a message. Its built-in checks warn about combinations macOS uses ("Use Anyway") and block ones in Jot's menu. A combination another app registered can't be detected: macOS doesn't report it, so "taken" means taken by macOS. `scripts/bundle.sh` must copy the package's resource bundle (`KeyboardShortcuts_KeyboardShortcuts.bundle`) into `Jot.app/Contents/Resources`, or the recorder crashes when it shows its texts. Check that the hotkeys work while the Capture Panel's menus are open (the package advertises this), and that the first-launch hint (ticket 14) shows the current hotkeys.

**Blocked by:** 04, 06

**Status:** ready-for-agent

- [ ] Each hotkey has a recorder control showing the current combination
- [ ] A newly recorded combination works immediately from any app; the old one stops working
- [ ] Unavailable combination → message shown, previous hotkey still active
- [ ] Same combination for both → rejected with a message
- [ ] Restore defaults resets both to `⌃⌥N` / `⌃⌥F`
- [ ] Choices persist across relaunch
