# 23: Paragraph gaps: no number, no height

**What to build:** The blank line that Return puts between paragraphs (ADR 0004) gets no line number and isn't counted, so the paragraph after Return is line 2, not line 3. Only paragraph gaps are skipped, with the editor's own rule (`MarkdownStyle.isParagraphGap`: the first blank line directly after a non-blank one, drawn as spacing); further blank lines are visible empty lines and keep their numbers. The empty last line after a trailing break is never a gap. Reverses ticket 16's "paragraph-gap blank lines are numbered" (decided 2026-10-09, after the user found the cursor "jumping to line 3"); the numbers no longer match the file's line numbers in other editors once a Note has paragraphs. The file content doesn't change: Return still writes `\n\n`.

**Changed after the user tried it (2026-10-09):** with the gap unnumbered but still half a line high, the jump from line 1 to 2 looked like something was missing. From three rendered variants (half line, quarter line, none) the user chose none: the gap now has no height (a 1 pt font, no line spacing, maximum line height 0.01; first tried with only a smaller font, which still left about 3 pt from the editor's 2 pt line spacing, so lines after Return looked further apart than after Shift-Return), so the paragraph after Return sits right below, like after Shift-Return; a second Return shows an empty, numbered line. In the editor, Return and Shift-Return now look the same.

**Blocked by:** 16

**Status:** done

- [x] After typing a line and Return, the cursor's line shows 2, directly below line 1
- [x] Shift-Return lines and extra blank lines are numbered
- [x] The gutter stays aligned while typing, scrolling and changing the font size
- [x] Blank lines' numbers sit level with where their text would be (fixed 2026-10-10: AppKit puts a lone line break's glyph at the bottom of the line, so the gutter takes a blank line's baseline from its font)
