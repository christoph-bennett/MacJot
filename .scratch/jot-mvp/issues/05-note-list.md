# 05: Note List: browse and reopen Notes

**What to build:** The Capture Panel gains the Note List sidebar, collapsed by default and toggled with `⌃⌘S` (was `⌘\`, changed for German keyboard layouts). It lists Notes in the Notes Folder sorted by last modification, newest first; each row shows the Title, a relative date ("2h", "Mon") and a one-line preview. Clicking a row opens that Note in the editor with the cursor where the user last left it (cursor positions are stored as app preferences, never in the file). Each row has a context menu, mirrored by a `⋯` menu in the editor: **Reveal in Finder**, **Open in Default App**, **Copy as Markdown**, **Move to Trash** (system Trash; asks for confirmation since user feedback, see story 64). With the Note List focused, ⌫, ⌦ (fn-⌫) and ⌘⌫ move the selected Note to the Trash and open the next one, like Mail. The status item menu gains **Show Notes**, which opens the panel with the sidebar expanded.

**Blocked by:** 01

**Status:** done

- [ ] `⌃⌘S` toggles the sidebar; collapsed when opened via New Note
- [ ] Notes sorted newest-modified first; editing a Note moves it to the top
- [ ] Row shows Title, relative date, one-line preview
- [ ] Selecting a Note saves the current one (rename-on-leave applies) and opens the selected one with its remembered cursor position
- [ ] Reveal in Finder, Open in Default App, Copy as Markdown, Move to Trash work from both the context menu and `⋯`
- [ ] Move to Trash uses the system Trash, no dialog, and the row disappears
- [ ] Show Notes opens the panel with the sidebar expanded
- [x] Seam 1 tests cover Note List ordering, Title and preview derivation

**Amended in ticket 11 (after the user tried it):** trashing the open Note, by Delete key, context menu or ⋯ menu, moves on to its neighbour in the list (else the most recent Note) instead of a new blank Draft, and focus stays where it was, so the Delete key keeps working. A Draft appears only when no Notes are left.
