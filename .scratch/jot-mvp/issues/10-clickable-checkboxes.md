# 10: Clickable checkboxes

**What to build:** In the styled editor, checklist items render their `[ ]` / `[x]` as a clickable checkbox. Clicking it toggles the box in the underlying text, autosaves like any edit, and doesn't move the user's cursor or selection. The toggle at a position is a core editing command.

**Blocked by:** 07, 09

**Status:** done

- [x] `- [ ]` and `- [x]` render as unchecked/checked boxes
- [x] Clicking toggles the text between `[ ]` and `[x]` and the file is saved
- [x] Cursor and selection are unchanged after clicking
- [x] Toggle is undoable
- [x] Seam 2 test covers toggling at a position

**Added after the user tried it:** a checked item's text (not the box) is struck through and dimmed. The cursor treats the box and the spaces after it as one unit: it can't stop inside the hidden brackets or between the box and the item's text. Boxes are drawn on bullet items only (`1. [ ]` isn't a checklist for Return or the toolbar either), and aren't clickable inside code blocks. Undo toggles the box back rather than using the text view's own undo, so the cursor never moves.
