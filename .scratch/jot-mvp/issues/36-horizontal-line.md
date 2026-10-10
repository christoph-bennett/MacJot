# 36: Horizontal line

**What to build:** **Horizontal Line** as the last item of the Formatting Toolbar's heading pop-up, after a separator (decided 2026-10-10; there's no room for another button). It inserts `---` on a line of its own at the cursor, as its own paragraph (blank lines around it, ADR 0004), and places the cursor after it. The editor draws a `---`, `***` or `___` line as a thin rule across the text area, with the characters themselves dimmed like the `#` of headings. A `---` directly under a line of text is a Markdown heading underline (setext), not a rule; the inserted one never is, thanks to the blank line before it.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] The heading pop-up ends with a separator and "Horizontal Line"; choosing it inserts `---` as its own paragraph, cursor after it, one undo step
- [ ] `---`, `***` and `___` lines show as a thin rule with dimmed characters, in light and dark mode
- [ ] Frontmatter (`---` at the very top) and `---` inside a code block aren't drawn as rules
