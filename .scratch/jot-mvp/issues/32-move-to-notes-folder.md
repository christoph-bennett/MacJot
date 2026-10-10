# 32: Move to Notes Folder

**What to build:** An Outside File (ticket 31) can be moved into the Notes Folder, where it becomes an ordinary Note (ADR 0007, decided 2026-10-10). The action is the default (blue) **Move to Notes Folder** button at the right of the read-only bar, and a **Move to Notes Folder** item in the Outside File's context menu and the editor's `⋯` menu, after a separator, where Notes have Move to Trash.

- **Moving, not copying:** the file leaves its original place. Moving out of Desktop, Downloads, iCloud Drive or an external volume may bring up macOS's one-time folder prompt; no Full Disk Access.
- **Name:** the file keeps its name, `.markdown` becomes `.md`, and no Date Prefix is added. On a clash with a file in the Notes Folder it gets `-2`, `-3`, … (ADR 0003's rule): `ideas.md` → `ideas-2.md`. Afterwards it's treated like any opened Note: renamed after its Title only once the Title changes.
- **Between volumes** (e.g. from a USB stick): copy, then delete the original; if the delete fails, the copy is removed again, so there are never two.
- **When it fails** (the folder prompt denied, a read-only volume, no permission to remove the file): the alert "MacJot couldn't move this file." with the reason; the file stays where it was, still read-only.
- **After the move:** the bar disappears, the Formatting Toolbar becomes active, the cursor is placed in the text and editing works as for any Note. The file keeps its modification date, so in the Note List it sits where that date puts it, selected and scrolled into view, without the lock. There's no undo in MacJot; the user can move it back in Finder.

**Blocked by:** 31

**Status:** ready-for-agent

- [ ] The bar's button and the menus' item move a Desktop file into the Notes Folder; the original is gone from the Desktop
- [ ] Afterwards it's editable, has no bar or lock, and sits in the Note List by its modification date, selected
- [ ] `Shopping Ideas.md` keeps its name; `notes.markdown` becomes `notes.md`; a clash gives `-2`; no Date Prefix
- [ ] Changing its Title afterwards renames it as for any Note
- [ ] A failed move (e.g. a read-only volume, or "Don't Allow" in the folder prompt) shows the alert and leaves the file where it was, read-only; never two copies
