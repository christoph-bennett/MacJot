# 44: Frontmatter Section

**What to build:** A Note that starts with frontmatter shows it in a visually separate, collapsible **Frontmatter Section** at the top of the editor (decided 2026-11-15, spec 0002, ADR 0010). It applies to every Note with closed frontmatter, not only Clips, and never changes the file's text.

- A header row with a chevron sits above the frontmatter. Collapsed, the frontmatter lines take no height (the way paragraph gaps do) and the header shows one summary line: `source · page` (for example "Safari · Personal — Finis — Write your book") when either exists, otherwise "Properties".
- Expanded, the raw YAML stays editable in the existing grey monospace on a faintly tinted band with a hairline below it, in light and dark.
- The cursor can't land inside the collapsed lines, as with paragraph gaps; a Find match inside the section expands it.
- Settings > Editor gets "Expand frontmatter when a Note opens", off by default. A manual toggle, by chevron or by View > Show/Hide Frontmatter (⌥⌘P, greyed out in a Note without frontmatter), lasts only while the Note stays open and is stored nowhere.
- The frontmatter lines get no line numbers and aren't counted; the Title is line 1.

The Note stays one text buffer, so saving, undo, Find and the Recovery Copy behave as before. Because Notes from other tools carry frontmatter too, this is the only part of spec 0002 that changes how existing Notes look, and it ships before any Clip code.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Seam 2 tests: the frontmatter range, the summary line (with both `source` and `page`, with one, with neither), and line numbering that skips the frontmatter so the Title is line 1; existing frontmatter and line-number tests pass unchanged.
- [ ] A Note with frontmatter opens collapsed by default and expanded when the Settings option is on; a Note without frontmatter looks exactly as before.
- [ ] Chevron and ⌥⌘P toggle the section; the menu item is disabled without frontmatter; the toggle isn't remembered when the Note is closed and reopened.
- [ ] The cursor skips the collapsed lines with the arrow keys and clicks; Find expands the section on a match inside it.
- [ ] Editing the expanded YAML saves, undoes and autosaves like any text; the file on disk is byte-identical to what the editor holds.
- [ ] The line-number gutter shows no overlaps or gaps when collapsing, expanding and typing in the section (checked with the offscreen harness used for the gutter fix).
- [ ] Manual check in light and dark: the band, hairline and summary line read as a separate section; the Notes in `~/Documents/MacJot` with frontmatter look right.
