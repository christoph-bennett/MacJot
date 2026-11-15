# 46: Clip Hotkey and the Accessibility permission

**What to build:** A third global hotkey, the **Clip Hotkey**, can be recorded, cleared and restored in Settings > Shortcuts (decided 2026-11-15, spec 0002, ADR 0005, ADR 0011). It defaults to ⌃⌥C, uses the same recorder and conflict warnings as the Capture and Search Hotkeys, and is included in Restore Defaults (a default another app holds isn't restored, as today).

Under the recorder, a status line shows "Accessibility access: granted" or "not granted" and an "Open Privacy Settings" button that opens the Accessibility pane. The status updates when the permission changes while Settings is open. Pressing the Clip Hotkey does nothing visible yet beyond asking the system for the permission once when it's missing; the Clip itself is ticket 47. This slice is demoable on its own: the hotkey registers, is configurable and warns about conflicts, and the permission status is right.

**Blocked by:** 43 (Sign the app with the Apple Development identity): without a stable signature the grant resets at every install, so the status couldn't be checked meaningfully.

**Status:** ready-for-agent

- [ ] The Clip Hotkey is ⌃⌥C on a fresh install and is registered globally, also from full-screen apps; recording another combination re-registers it at once.
- [ ] The recorder warns when the combination is the Capture or Search Hotkey or one macOS uses, and doesn't save a rejected combination; clearing it turns the hotkey off.
- [ ] Restore Defaults restores it like the other two, and keeps a hotkey another app holds.
- [ ] The status line reads "granted" or "not granted" correctly, updates after granting in System Settings without reopening Settings, and the button opens the Accessibility pane.
- [ ] Pressing the hotkey without the permission asks the system for it once (the prompt doesn't repeat on every press).
- [ ] Existing hotkey tests pass unchanged; the state matrix in spec 0001's manual list is rechecked for the three hotkeys.
