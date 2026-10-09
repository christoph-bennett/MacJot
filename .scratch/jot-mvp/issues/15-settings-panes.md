# 15: Settings panes

**What to build:** The Settings window gets the layout of sindresorhus/Settings in its segmented-control style (github.com/sindresorhus/Settings, MIT; our own code, no dependency): a segmented control centred in the title bar switches between panes, and each pane uses the classic Mac settings layout, with labels in a right-aligned column and controls left-aligned next to them (SwiftUI `Form` with `.formStyle(.columns)`), instead of today's grouped boxes. Switching panes crossfades the content and animates the window to the new pane's height, keeping its top edge in place. No toolbar icons.

Panes, as agreed with the user (later tickets add their settings to these):

- **General:** Notes Folder, Date Prefix (today); launch at login, ask before Trash, reset panel (ticket 14)
- **Editor:** font size, line numbers, relative dates in the Note List (ticket 14). Shown once it has a setting.
- **Shortcuts:** Capture and Search Hotkeys, shown read-only until ticket 13 adds recorders and Restore Defaults

**Blocked by:** 12

**Status:** done

- [x] A segmented control centred in the title bar lists the panes; the window's title is the selected pane's name (Window menu, VoiceOver)
- [x] Panes use a right-aligned label column, controls left-aligned; checkboxes rather than switches
- [x] Switching panes crossfades and resizes the window smoothly, top edge fixed
- [x] The last selected pane is shown when Settings opens again, also after relaunch
- [x] Everything Settings does today still works (Notes Folder chooser and its dialogs, Date Prefix)
- [x] Shortcuts shows both hotkeys as symbols for the current keyboard layout (e.g. `⌃⌥N`)
