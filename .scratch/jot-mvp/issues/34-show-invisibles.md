# 34: Show invisible characters

**What to build:** The editor can show invisible characters as faint symbols in the secondary text colour (decided 2026-10-10): `·` for a space, `→` for a tab, `¬` at a single line break (Shift-Return) and `¶` at the end of a paragraph. The paragraph gap itself (ADR 0004) stays invisible; the `¶` before it marks it. They're drawn, never part of the text: copying, saving and Find see the text as it is. Switched with a **Show invisible characters** checkbox in Settings > Editor and the menu item **View > Show Invisibles** (⌥⌘I, as in TextEdit and BBEdit), which stay in sync (the menu item shows a checkmark); off by default. The panel catches ⌥⌘I itself, like its other shortcuts.

**Blocked by:** none

**Status:** done

- [x] Settings > Editor has "Show invisible characters", off by default; View > Show Invisibles (⌥⌘I) toggles the same setting, with a checkmark while on
- [x] Spaces, tabs, single line breaks and paragraph ends show their symbols, faintly, in light and dark mode
- [x] Copying, saving and Find are unaffected; the cursor and selection move as before
- [x] Works with wrapping off (ticket 28), line numbers and the current-line band
