# 49: Clip Hotkey captures the selection

**What to build:** With text selected in any app, pressing the Clip Hotkey creates a Note from it (decided 2026-11-15, spec 0002, ADR 0011; rewritten after a sparring session). It uses the Note creation from ticket 47 and the Clip Confirmation from ticket 48, so a successful Clip already shows its pill and a failed capture can still be rescued with Clip from Clipboard.

The sequence, written against ticket 45's findings: record the frontmost app and its front window's title; wait until the hotkey's modifiers are released; snapshot the general pasteboard; send ⌘C with only the Command flag set; wait up to about 0.5 s for the pasteboard to change, then until it has been stable for about 50 ms; read the plain text; restore the snapshot, marked transient where the pasteboard allows. No change in time means "no selection": nothing is restored and the clipboard is left untouched. Concealed items are never read. Types that can't be copied back are skipped and lost on restore.

The Note gets `source` (the app), `page` (the window title with a trailing app name and browser profile removed; left out for Terminal and iTerm) and `url` (the page address, only when the copy carries one on the pasteboard, e.g. Chrome's and Edge's `org.chromium.source-url`, read before the clipboard is restored; Safari and others give none and get no `url`). Where the pasteboard carries `org.nspasteboard.source` (an app's bundle identifier, resolved to the app's name), Clip from Clipboard (ticket 47's path, amended here) also uses it as `source`; for the hotkey the frontmost app's name wins. Decided 2026-11-15: no AppleScript or System Events, not even for Safari; MacJot takes what the Accessibility API and the pasteboard give, and whatever isn't there isn't there. The Note creation from ticket 47 and the frontmatter writer get an optional `url` for this. A status-menu item "Clip Selection", showing the hotkey, does the same, so a hotkey that doesn't fire can be told apart from a capture that fails.

Failures show an alert that says what happened (the permission is called “Device Control and Data Access” in System Settings on macOS 27, so the alert says that): nothing selected (or a field that blocks copying), MacJot itself in front ("Select text in another app"), or the Accessibility permission missing (pointing to Settings > Shortcuts). A whitespace-only selection counts as empty. If ticket 45 found that macOS asks before a program reads the pasteboard, this ticket handles that flow first.

**Blocked by:** 45 (Pasteboard and ⌘C inspector), 46 (Clip Hotkey and the Accessibility permission), 47 (Clip from the clipboard), 48 (Clip Confirmation and Last Clip).

**Status:** ready-for-agent

- [ ] Seam 3 tests with fakes for the pasteboard, key sender, clock and frontmost app: the clipboard is restored in every outcome that changed it; no change within the wait gives "no selection" and leaves the clipboard untouched; MacJot in front fails with its own reason; the restore is marked transient; the ⌘C carries only the Command flag and waits for the modifiers to be released; a pasteboard still changing is read only after it settles; concealed items are never read.
- [ ] Seam 2 tests for the window-title cleaning: Chrome with a profile, Firefox, Safari, Pages, Terminal and iTerm (`page` left out), and no title.
- [ ] In Safari, Chrome, Pages and Terminal, the hotkey makes a Note with the right `source` and a clean `page`; the pill shows; the clipboard holds what it held before, including a non-text item (an image copied beforehand).
- [ ] Holding ⌃⌥ while pressing the hotkey still copies in all four apps.
- [ ] Focus stays in the source app and the Capture Panel doesn't open; "Clip Selection" in the status menu works the same.
- [ ] Each failure shows its alert; the missing-permission alert points to Settings > Shortcuts.
- [ ] Manual check of the three failure modes in each of the four apps: the hotkey fires, the pill shows, and the Note's Title is what was expected.
- [ ] A Clip from Chrome or Edge has a `url` line with the page's address; one from Safari, Pages or Terminal has none; the frontmatter writer is tested with and without `url` (quoting for a URL with a colon, `#` or `&`).
- [ ] A Clip from Clipboard whose pasteboard carries `org.nspasteboard.source` (e.g. after pasting from Raycast's history) gets that app's name as `source`; without the marker it still has none.
