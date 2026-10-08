# 04: Settings window and Date Prefix

**What to build:** The status item menu gains **Settings…**, which opens a Settings window (SwiftUI hosted in AppKit). Its first option is the **Date Prefix** toggle (off by default). When on, new Notes get a `yyyy-mm-dd-` filename prefix for their creation day (from the injected clock). The prefix is preserved when the Note is later renamed after a Title change. Toggling the setting affects only Notes created afterwards; existing files are never renamed. A Note's created date comes from its Date Prefix if present, else the file system's creation date.

**Blocked by:** 03

**Status:** done

- [x] Settings… menu item opens a single Settings window (re-focuses if already open)
- [x] Date Prefix toggle persists across relaunch; default off
- [x] Prefix on, created 2026-10-08 → `2026-10-08-<slug>.md`
- [x] Prefix on, Note later retitled → `2026-10-08-<new-slug>.md` (date unchanged)
- [x] Prefix switched on after a Note exists → existing filename unchanged
- [x] Created date derived from prefix when present, else file creation date
- [x] Seam 1 tests cover the prefix cases with an injected clock
