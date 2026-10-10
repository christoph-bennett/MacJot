# 29: Highlight the current line

**What to build:** A faint band behind the line the cursor is on, with a **Highlight current line** checkbox in Settings > Editor, on by default (decided 2026-10-10). The band covers the whole line, all its wrapped rows, matching the line numbers; it spans the text area only, and the current line's number in the gutter is drawn in a stronger colour instead of the band. Only with a plain cursor: no band while text is selected. A system colour that follows light and dark mode (e.g. a low-alpha label or accent colour), faint enough not to compete with the text or the find highlights. The cursor never rests on a paragraph gap, so the band never sits on one.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Settings > Editor shows "Highlight current line", checked by default; unchecking it removes the band and the stronger number
- [ ] The band follows the cursor (typing, arrows, clicks) and covers every row of a wrapped line
- [ ] Selecting text removes the band; a plain cursor brings it back
- [ ] The current line's number is drawn stronger; with line numbers off, only the band shows
- [ ] Looks right in light and dark mode, and with find highlights (⌘F)
