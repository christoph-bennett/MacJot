# 06: Search and the Search Hotkey

**Already done in ticket 05 follow-up:** the Search Hotkey `⌃⌥F` and the full state matrix exist; from hidden it opens the Note List focused with the most recent Note in the editor. What remains here is the search field: `⌃⌥F` should then focus it instead of the list.

**What to build:** The Note List gets a search field that filters live by Title and body, case- and diacritic-insensitive, held in memory. While searching, each row's preview shows the snippet around the match. Arrow keys move the selection and Return opens the selected Note. `Esc` clears a non-empty search; a second `Esc` closes the panel. The **Search Hotkey** (`⌃⌥F`, fixed default for now) summons the panel with the sidebar open, search focused and the most recently modified Note in the editor. The full hotkey state matrix applies:

| Panel state | Capture Hotkey | Search Hotkey |
|---|---|---|
| Hidden | Show panel with a new Draft | Show panel, Note List open, search focused |
| Visible, not key | Bring to front, keep content | Bring to front, focus search |
| Key, same mode | Hide | Hide |
| Key, other mode | Switch to new Draft | Switch to search |

**Blocked by:** 02, 05

**Status:** done

- [x] Typing in search filters live; `uber` matches `Über`, `MEETING` matches `meeting`
- [x] Matches in body (not only Title) are found; preview shows the match snippet
- [x] Arrow keys move selection; Return opens the Note
- [x] `Esc` clears search first, then closes the panel
- [x] `⌃⌥F` from any app opens the panel in search mode with the most recent Note shown
- [x] Every cell of the state matrix behaves as specified (verified manually)
- [x] Seam 1 tests cover search matching (case/diacritics, body vs Title) and snippets
