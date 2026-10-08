# 11: External changes

**What to build:** Jot watches the Notes Folder (FSEvents) and reflects changes made by other tools or sync: Notes added, edited, renamed or deleted elsewhere appear, update, or disappear in the Note List. If the open Note changes on disk and the user has no unsaved edits, the editor silently reloads it (keeping the cursor as close as possible); if the user has unsaved edits, the local version wins and overwrites the file on the next flush. Jot's own writes and renames don't cause spurious reloads. The file-system event source is injected into the Notes Folder so tests drive it manually.

**Blocked by:** 05

**Status:** ready-for-agent

- [ ] A file created in the folder by another app appears in the Note List
- [ ] A Note put back from the Trash ("Put Back" in Finder) appears in the Note List straight away, without switching Notes (reported by the user; today it only shows up on the next list reload)
- [ ] Editing a non-open Note elsewhere updates its Title, preview and position
- [ ] Renaming or deleting a file elsewhere updates or removes the row
- [ ] Open Note, no unsaved edits, changed elsewhere → editor shows new content
- [ ] Open Note with unsaved edits, changed elsewhere → local text kept and written on next flush
- [ ] Jot's own saves and rename-on-leave don't trigger a reload
- [ ] Seam 1 tests cover each case with a manually driven event source
