# 10: Clickable checkboxes

**What to build:** In the styled editor, checklist items render their `[ ]` / `[x]` as a clickable checkbox. Clicking it toggles the box in the underlying text, autosaves like any edit, and doesn't move the user's cursor or selection. The toggle at a position is a core editing command.

**Blocked by:** 07, 09

**Status:** ready-for-agent

- [ ] `- [ ]` and `- [x]` render as unchecked/checked boxes
- [ ] Clicking toggles the text between `[ ]` and `[x]` and the file is saved
- [ ] Cursor and selection are unchanged after clicking
- [ ] Toggle is undoable
- [ ] Seam 2 test covers toggling at a position
