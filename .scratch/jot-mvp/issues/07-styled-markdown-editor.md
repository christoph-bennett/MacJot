# 07: Styled Markdown editor

**What to build:** The editor renders Markdown as styled text while keeping the syntax in the text: syntax markers are visible but dimmed, and bold, italic, strikethrough, headings (H1–H3 sizes), bullet/numbered/check lists, quotes, inline code and links are styled accordingly. ~~The Title line is always emphasised even without `#`.~~ Dropped after trying it (confusing); only `#` makes a heading. Prose uses SF Pro; inline code and syntax markers use SF Mono. Appearance follows system light/dark. What the user sees is exactly what's stored; no characters are added or removed by styling.

**Paragraphs (added after ticket 03 feedback, see ADR 0004):** Return outside a list or quote starts a new paragraph: it inserts a blank line (`\n\n`), so the text shows as separate paragraphs in every Markdown renderer (Quick Look plugins, GitHub), as Stik's files do. Shift-Return inserts a single line break for lines that belong together. Return on a line that is already blank inserts a single `\n`, so repeated Returns don't multiply blank lines. In list items, quotes and frontmatter Return inserts a single `\n` (ticket 09 adds list continuation on top). The editor shows the blank line between paragraphs as paragraph spacing rather than a full empty line. The Return behaviour is a core editing command (Seam 2).

**Blocked by:** 01

**Status:** done

- [ ] Each supported construct renders styled with dimmed markers
- [x] ~~Title line emphasised~~ dropped: the first line is styled like any other line
- [ ] SF Pro for prose, SF Mono for inline code and markers
- [ ] Switching system light/dark updates the editor live
- [ ] Saved file content is byte-identical to the typed text
- [ ] Styling stays responsive while typing in a Note of a few thousand lines
- [x] Return at the end of a paragraph or heading (incl. the Title line) inserts `\n\n` with the cursor on the new paragraph
- [x] Return in the middle of a paragraph splits it into two paragraphs separated by a blank line
- [x] Shift-Return inserts a single `\n`
- [x] Return on a blank line, in a list item, in a quote or inside frontmatter inserts a single `\n`
- [ ] Blank lines between paragraphs are shown as paragraph spacing, not as a full empty line
- [ ] A Note typed as `Biggie Smalls is the illest` Return `Biggie Biggie Biggie` previews as two separate lines in FluxMarkdown Quick Look
- [x] Seam 2 tests cover Title-line detection (incl. leading blank lines and frontmatter) and the Return command cases above
