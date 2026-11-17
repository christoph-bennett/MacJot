# 55: Sidebar button in the editor toolbar; `⋯` disabled for a Draft

**What to build:** Two small fixes to the bar above the editor, found while testing ticket 54 (2026-11-17, grilled).

1. **Show/hide the Note List by button.** A summon with the Capture Hotkey opens the panel with the Note List collapsed, and the only ways to open it were ⌃⌘S and the View menu. A `sidebar.left` button at the leading end of the Formatting Toolbar row now toggles the Note List, always visible, with the tooltip "Show Note List" or "Hide Note List" and the shortcut ⌃⌘S. It does what the shortcut does (same animation, search focus rules unchanged).
2. **`⋯` is disabled while the Note has no file.** A Draft has no file, so the Note actions menu has nothing to offer and the button silently did nothing while looking clickable. It is now dimmed and not clickable for a Draft, and enabled again once the Note gets its file (when its Title is finished) and for an opened Note.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] A new Draft summoned by hotkey shows the sidebar button; clicking it shows the Note List, clicking again hides it, matching ⌃⌘S.
- [x] The button is also there with the Note List open, and its tooltip follows the state.
- [x] At the narrowest panel width the sidebar button, the formatting groups and `⋯` still fit without overlapping, or the toolbar degrades as it does today.
- [x] `⋯` is dimmed and does nothing on a Draft; it works on a Note with a file and on the Draft once it has one.
- [x] Accessibility labels are set for the new button.
- [x] Manual check in light and dark; committed only after the user says "commit".
