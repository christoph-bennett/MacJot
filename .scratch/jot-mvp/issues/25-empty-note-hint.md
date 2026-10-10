# 25: Hint while a Note is empty

**What to build:** While the open Note would be moved to the Trash on leave, the editor shows the dimmed hint "Leave this note empty to move it to the Trash." on its first line, where the user would type: editor font, the system's placeholder text colour; it disappears with the first character (decided 2026-10-10). Exactly when leaving would trash it, never otherwise: the Note has a file and its text is blank now, but wasn't blank when saved (`NotesFolder.leave`'s rule). A blank **Draft** shows nothing, and neither does a file that was already blank when opened. Chosen over a confirmation dialog (BACKLOG): trashing happens on leave, where a dialog would block or arrive in a closing panel, and nothing is lost. The rule belongs in JotCore next to `leave()` so the hint and the trashing can't disagree.

**Blocked by:** 26 (same rule, touched there)

**Status:** ready-for-agent

- [ ] Open a Note, delete all its text: the hint appears; type a character: it's gone
- [ ] A new blank Draft shows no hint
- [ ] A Note whose file was blank when opened shows no hint
- [ ] The hint follows the font size setting and light/dark mode, and isn't part of the text (not saved, not selectable)
