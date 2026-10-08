# 03: Full filename rules, Title-finished creation and rename-on-leave

**What to build:** Every Note's filename follows the full rules in ADR 0003: leading Markdown is ignored (`#`, `- [ ]`, `>`, `**` …), accented characters are transliterated to ASCII and remaining non-ASCII dropped, the result is lowercased with non-alphanumerics collapsed to single `-` and trimmed, capped at 60 characters on a word boundary, `untitled` when nothing usable remains, and `-2`, `-3` … on collision. The Title is the first non-blank line. When the user changes the Title, the file is renamed only when they leave the Note (panel close, `⌘N`, switching Notes, quit), never while typing. A Note the user empties is moved to the system Trash when they leave it. Existing frontmatter is preserved verbatim and ignored for Title derivation. The trash operation is injected into the Notes Folder.

**Title-finished creation (added after ticket 01 feedback):** a Draft's file is only created in the Notes Folder once its Title line is finished, meaning a line break follows the first non-blank line, or when the Note is left with content (panel close, `⌘N`, quit). Until then, autosave keeps running but writes the **Recovery Copy**: a single hidden file in `~/Library/Application Support/Jot/` (location injected into the Notes Folder). Creating the Note's file deletes the Recovery Copy. On launch, a Recovery Copy with content is turned into a normal Note (crash recovery); a blank one is discarded. Rename-on-leave still applies to Titles edited after the file exists. See ADR 0003.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `# Über Änderungen!` → `uber-anderungen.md`
- [ ] `- [ ] Call Anna` → `call-anna.md`
- [ ] `🎉🎉` → `untitled.md`
- [ ] Two Notes titled `Meeting` → `meeting.md`, `meeting-2.md`
- [ ] Title preceded by blank lines → slug of the first non-blank line
- [ ] Long Titles are cut to ≤ 60 chars at a word boundary
- [ ] Retitling renames the file on leave, not while typing; the open Note keeps saving to its current path until then
- [ ] Typing `Meeting wi`, pausing past the autosave delay, then finishing `Meeting with Anna` + Return creates only `meeting-with-anna.md` (no intermediate file in the Notes Folder)
- [ ] Before the Title is finished, autosave writes the Recovery Copy and nothing in the Notes Folder
- [ ] A single-line Draft is materialised when the Note is left (close, `⌘N`, quit)
- [ ] Materialising the Note deletes the Recovery Copy
- [ ] Constructing the Notes Folder with a Recovery Copy present turns it into a Note; a blank Recovery Copy is just removed
- [ ] Emptying a Note and leaving it moves the file to the system Trash
- [ ] A file with frontmatter keeps it byte-for-byte; Title comes from the first non-blank line after it
- [ ] All of the above covered by Seam 1 tests asserting resulting filenames on disk (recording trash injected)
