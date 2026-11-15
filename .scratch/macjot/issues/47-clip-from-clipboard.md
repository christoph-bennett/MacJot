# 47: Clip from the clipboard

**What to build:** A status-menu item "Clip from Clipboard" makes a new Note from the text on the clipboard (decided 2026-11-15, spec 0002, ADR 0010; rewritten after a sparring session). It needs no permission, so it is the first Clip that exists, and it stays as the fallback when capturing a selection fails: copy by hand, then choose it.

- The Note is written straight to the Notes Folder as a Note with a finished Title (not a Draft), without opening the Capture Panel or taking focus. Filename, Date Prefix and collision suffix follow ADR 0003; repeating the same text makes a second Note.
- It starts with frontmatter holding only `created` (ISO 8601, local time with offset, seconds). MacJot can't know the Source of clipboard text, so there is no `source` or `page`; the creation takes both as optional so that tickets 49 and 50 can fill them. Values are double-quoted only when YAML needs it.
- The body is the text, except that leading blank lines and lines with no letter or digit are dropped and the first line's leading whitespace trimmed. The Title is the first non-blank line after the frontmatter. If it would give an `untitled` filename (Cyrillic, emoji), the file is named `clip-<app>`, or `clip` when there's no app, under the same Date Prefix and collision rules.
- Empty or whitespace-only clipboard text makes no Note and shows an alert saying the clipboard has no text. Non-text clipboards (an image) get the same alert for now.

There's no confirmation yet (ticket 48). The demo: the Note appears in the Note List and in the Notes Folder, titled sensibly, for text copied from Safari, Chrome, Pages and Terminal.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Seam 1 tests over a temporary Notes Folder with an injected clock: the `created` key and its format, the Title after the frontmatter, dropped leading decoration lines and trimmed whitespace, the `clip-<app>` and `clip` filenames for an unnameable Title, the filename with and without a Date Prefix, the collision suffix for a repeated text, and no file for whitespace-only text; the optional `source` and `page` keys written and quoted correctly when given (a title with a colon, a quote, a leading symbol).
- [ ] Seam 2 tests (table-driven) for the text cleaning: leading blank and symbol-only lines, whitespace trimming, a first line of only Cyrillic or emoji, a selection that is only decoration.
- [ ] Text copied from Safari, Chrome, Pages and Terminal makes a Note whose Title reads sensibly; a terminal selection starting with a rule of box characters doesn't get that rule as its Title.
- [ ] An open Capture Panel shows the new Note in its list without a reload; focus stays where it was.
- [ ] The empty and non-text clipboard cases show the alert and create nothing.
- [ ] The Note's frontmatter shows in the Frontmatter Section if ticket 44 is done, and as plain YAML otherwise.
