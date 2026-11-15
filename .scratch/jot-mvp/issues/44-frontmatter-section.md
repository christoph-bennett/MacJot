# 44: Frontmatter Section: display and toggle

**What to build:** A Note that starts with closed frontmatter shows it in a visually separate, collapsible **Frontmatter Section** at the top of the editor (decided 2026-11-15, spec 0002, ADR 0010; narrowed after a sparring session, the Settings option and Find are ticket 51). It applies to every Note with closed frontmatter, not only Clips, and never changes the file's text.

- A header row with a chevron sits above the frontmatter. Collapsed, the frontmatter lines take no height and the header shows one summary line: `source · page` (for example "Safari · Personal — Finis — Write your book") when either exists, otherwise "Properties". Notes open collapsed for now; ticket 51 adds the setting.
- Expanded, the raw YAML stays editable in the existing grey monospace on a faintly tinted band with a hairline below it, in light and dark.
- The cursor can't land inside the collapsed lines (arrow keys, clicks, select-all and typing never enter hidden text), as with paragraph gaps. The chevron and View > Show/Hide Frontmatter (⌥⌘P, greyed out in a Note without frontmatter) toggle the section; the state lasts only while the Note stays open and is stored nowhere.
- The frontmatter lines get no line numbers and aren't counted; the Title is line 1.

The Note stays one text buffer, so saving, undo and the Recovery Copy behave as before. How the header row is drawn (a view over the editor, or a styled line in the text) is the implementer's decision, but it must not add anything to the file text. This is the same area as the line-number overlap fixed on 2026-11-15 (stale styling on zero-height rows), so every edit near the section is checked with the offscreen gutter harness.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] Seam 2 tests: the frontmatter range, the summary line (with both `source` and `page`, with one, with neither), and line numbering that skips the frontmatter so the Title is line 1; existing frontmatter and line-number tests pass unchanged.
- [ ] A Note with frontmatter opens collapsed; a Note without frontmatter looks exactly as before.
- [ ] Chevron and ⌥⌘P toggle the section; the menu item is disabled without frontmatter; the toggle isn't remembered when the Note is closed and reopened.
- [ ] The cursor skips the collapsed lines with arrows, clicks, ⌘A and typing; nothing can be typed into hidden text.
- [ ] Editing the expanded YAML saves, undoes and autosaves like any text; the file on disk is byte-identical to what the editor holds.
- [ ] A random-edit run with the offscreen harness (Return, Backspace, typing, collapsing and expanding in and around the section) shows no overlapping or doubled line numbers.
- [ ] Manual check in light and dark: the band, hairline and summary line read as a separate section; the Notes in `~/Documents/MacJot` with frontmatter look right.
