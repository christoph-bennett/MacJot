# 22: Note List empty states

**What to build:** The Note List says why it's empty, from the HIG audit (`.scratch/hig-audit/`, finding 10): a search with no matches shows a centred grey "No Results" in the list, an empty Notes Folder shows "No Notes". Apple's standard look for this is SwiftUI's `ContentUnavailableView` (the `.search` variant for searches); in the AppKit list, either host one or match its look (secondary label colour, centred in the list's visible area). **Changed after the user tried it (2026-10-09):** "No Notes" never showed, because opening the Note List in an empty folder opens a Draft, and the Draft had a row of its own ("New Note") even while blank. Decided: a blank Draft gets no row (`NoteSummary.listsDraft`); its row appears with the first text, so an empty folder says "No Notes" until the user types. This also applies with Notes in the folder: no "New Note" row at the top until the Draft has text. Then, as the Search Hotkey leaves the cursor in the search field, "No Notes" got a **New Note** button (Apple's text-button style for empty states rather than a bare "+"; same as ⌘N: starts a Draft and puts the cursor in the editor).

**Blocked by:** 19

**Status:** done

- [x] A search without matches shows "No Results"; clearing the search brings the Notes back
- [x] An empty Notes Folder shows "No Notes"; the first saved Note replaces it
- [x] "No Notes" has a New Note button that puts the cursor in a new Draft
- [x] A blank Draft has no row: an empty folder shows "No Notes" until the user types; the Draft's row then replaces it
