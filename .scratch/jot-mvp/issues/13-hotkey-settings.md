# 13: Hotkey settings

**What to build:** Settings lets the user record a new Capture Hotkey and Search Hotkey. A change re-registers the global hotkey immediately, without restart, and persists across relaunch. If a combination can't be registered (taken by the system or another app) or both hotkeys are set to the same combination, the user is told in Settings and the previous hotkey stays active. Defaults remain `⌃⌥N` and `⌃⌥F`, with a way to restore them.

**How** (ADR 0005, after looking at sindresorhus/KeyboardShortcuts with the user): use the package as a SwiftPM dependency; it replaces `GlobalHotkey.swift`. `KeyboardShortcuts.Name`s for capture and search with `initial:` ⌃⌥N / ⌃⌥F; `KeyboardShortcuts.Recorder` rows in Settings > Shortcuts (ticket 15's read-only rows, label column "Capture:" / "Search:"); `onKeyDown` handlers in `AppDelegate`; Restore Defaults calls `reset`. "Both the same" goes through the recorder's custom shortcut validation, with a message. Its built-in checks warn about combinations macOS uses ("Use Anyway") and block ones in Jot's menu. A combination another app registered can't be detected: macOS doesn't report it, so "taken" means taken by macOS. `scripts/bundle.sh` must copy the package's resource bundle (`KeyboardShortcuts_KeyboardShortcuts.bundle`) into `Jot.app/Contents/Resources`, or the recorder crashes when it shows its texts. Check that the hotkeys work while the Capture Panel's menus are open (the package advertises this), and that the first-launch hint (ticket 14) shows the current hotkeys.

**Implementation notes:**

- **Vendored, not fetched.** KeyboardShortcuts 3.1.0 (latest, Sept 2026) uses SwiftUI macros (`@Entry`, `#Preview`, and `@State`, which the macOS 27 SDK declares as a macro), whose plugins ship only with Xcode. Releases up to 2.4.0 don't use them, but they also lack the custom validation this ticket needs. So it's a local package in `Vendor/KeyboardShortcuts` with three small patches marked "Jot patch"; its README says how to update it. ADR 0005 has a note on this.
- **"Unavailable" is checked before saving.** The package drops a combination silently when registering it fails, after the old one is already gone. So the recorder's validation registers the candidate for a moment first (`Hotkey.problem(recording:)` → `HotkeyCheck` in JotCore). While the recorder records, Jot's own hotkeys are paused, so a failure means another app holds the combination exclusively. Most apps don't register exclusively, so this rarely triggers; macOS's own shortcuts get the package's "Use Anyway" warning. The same check runs at launch (a hotkey another app holds gets a red note under its recorder) and for Restore Defaults (a default another app holds isn't restored, with an alert).
- **Clearing a hotkey turns it off.** The recorder's clear button allows it; Restore Defaults brings it back. The first-launch hint leaves out a hotkey that's off (a reinstall keeps the hotkeys).
- **Defaults** are stored by `Name(_:initial:)` the first time, so existing users keep ⌃⌥N / ⌃⌥F.

**Blocked by:** 04, 06

**Status:** done

- [x] Each hotkey has a recorder control showing the current combination
- [x] A newly recorded combination works immediately from any app; the old one stops working
- [x] Unavailable combination → message shown, previous hotkey still active
- [x] Same combination for both → rejected with a message
- [x] Restore defaults resets both to `⌃⌥N` / `⌃⌥F`
- [x] Choices persist across relaunch
