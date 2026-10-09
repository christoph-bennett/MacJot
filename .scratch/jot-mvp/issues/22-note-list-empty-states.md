# 22: Note List empty states

**What to build:** The Note List says why it's empty, from the HIG audit (`.scratch/hig-audit/`, finding 10): a search with no matches shows a centred grey "No Results" in the list, an empty Notes Folder shows "No Notes". Apple's standard look for this is SwiftUI's `ContentUnavailableView` (the `.search` variant for searches); in the AppKit list, either host one or match its look (secondary label colour, centred in the list's visible area). The open Draft's row counts as content: with only a Draft, no message.

**Blocked by:** 19

**Status:** ready-for-agent

- [ ] A search without matches shows "No Results"; clearing the search brings the Notes back
- [ ] An empty Notes Folder shows "No Notes"; the first saved Note replaces it
- [ ] With only a Draft in the list, no message
