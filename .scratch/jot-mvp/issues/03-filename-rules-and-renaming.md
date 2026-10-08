# 03: Full filename rules and rename-on-leave

**What to build:** Every Note's filename follows the full rules in ADR 0003: leading Markdown is ignored (`#`, `- [ ]`, `>`, `**` …), accented characters are transliterated to ASCII and remaining non-ASCII dropped, the result is lowercased with non-alphanumerics collapsed to single `-` and trimmed, capped at 60 characters on a word boundary, `untitled` when nothing usable remains, and `-2`, `-3` … on collision. The Title is the first non-blank line. When the user changes the Title, the file is renamed only when they leave the Note (panel close, `⌘N`, switching Notes, quit), never while typing. A Note the user empties is moved to the system Trash when they leave it. Existing frontmatter is preserved verbatim and ignored for Title derivation. The trash operation is injected into the Notes Folder.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `# Über Änderungen!` → `uber-anderungen.md`
- [ ] `- [ ] Call Anna` → `call-anna.md`
- [ ] `🎉🎉` → `untitled.md`
- [ ] Two Notes titled `Meeting` → `meeting.md`, `meeting-2.md`
- [ ] Title preceded by blank lines → slug of the first non-blank line
- [ ] Long Titles are cut to ≤ 60 chars at a word boundary
- [ ] Retitling renames the file on leave, not while typing; the open Note keeps saving to its current path until then
- [ ] Emptying a Note and leaving it moves the file to the system Trash
- [ ] A file with frontmatter keeps it byte-for-byte; Title comes from the first non-blank line after it
- [ ] All of the above covered by Seam 1 tests asserting resulting filenames on disk (recording trash injected)
