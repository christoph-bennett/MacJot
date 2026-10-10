# 26: Trash an emptied Note with its full contents

**What to build:** When an emptied Note goes to the Trash on leave, the Trash copy has the **longest version saved since the Note was opened** (decided 2026-10-10), not the last autosave. Today autosave writes the shrinking text as the user deletes, so deleting with pauses can leave only a few characters in the Trash (select-all + Delete is fine). "Since opened" means this visit: the Note's text when it was opened counts as a version, and so does every save until it's left; a Note emptied halfway on an earlier visit goes to the Trash with what was left of it. Before moving the file to the Trash, `NotesFolder.leave()` writes that version back into it. Longest = most characters (UTF-16 length is fine). Pure logic in JotCore, test first.

**Blocked by:** none

**Status:** done

- [x] Open a Note, delete its text slowly (several autosaves), leave: the Trash copy has the full text
- [x] Add two lines, wait for an autosave, then empty it and leave: the Trash copy includes the two lines
- [x] Select-all + Delete still trashes the full text
- [x] A Note emptied halfway on an earlier visit goes to the Trash with the remaining half
