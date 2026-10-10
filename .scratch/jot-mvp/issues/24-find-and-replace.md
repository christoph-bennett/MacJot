# 24: Find and replace in the open Note

**What to build:** **Find** (GLOSSARY: within the open Note; **Search** stays across Notes in the Note List) with the standard macOS find bar in the editor: NSTextView's `usesFindBar` with incremental search, so matches highlight while typing. Shortcuts, the standard Mac set (decided 2026-10-10): ⌘F shows the find bar, ⌥⌘F shows it with replace, ⌘G / ⇧⌘G go to the next / previous match, ⌘E uses the selection for Find. They are listed in an **Edit > Find** submenu (Find…, Find and Replace…, Find Next, Find Previous, Use Selection for Find), as the HIG asks. The panel routes ⌘-shortcuts itself (`CapturePanel.sendEvent` → `handleShortcut`), so these must be handled there; with focus in the Note List's search field or the list, ⌘F still goes to the editor's find bar (focus moves to it). Esc in the find bar closes it and returns to the text, not hiding the panel.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] ⌘F shows the find bar; typing highlights matches in the open Note; Return / ⌘G and ⇧⌘G move between them
- [ ] ⌥⌘F shows find and replace; Replace and Replace All work and can be undone with ⌘Z
- [ ] ⌘E with a selection puts it in the find field
- [ ] Edit > Find lists all five with their shortcuts
- [ ] ⌘F while the Note List's search field has focus opens the editor's find bar
- [ ] Esc in the find bar closes it (the panel stays); switching Notes keeps or closes the bar sensibly and never finds in the previous Note's text
