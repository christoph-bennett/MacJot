# 07: Styled Markdown editor

**What to build:** The editor renders Markdown as styled text while keeping the syntax in the text: syntax markers are visible but dimmed, and bold, italic, strikethrough, headings (H1–H3 sizes), bullet/numbered/check lists, quotes, inline code and links are styled accordingly. The Title line (first non-blank line) is always emphasised (larger, bolder) even without `#`. Prose uses SF Pro; inline code and syntax markers use SF Mono. Appearance follows system light/dark. What the user sees is exactly what's stored; no characters are added or removed by styling.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Each supported construct renders styled with dimmed markers
- [ ] Title line emphasised with and without `#`; blank leading lines are skipped
- [ ] SF Pro for prose, SF Mono for inline code and markers
- [ ] Switching system light/dark updates the editor live
- [ ] Saved file content is byte-identical to the typed text
- [ ] Styling stays responsive while typing in a Note of a few thousand lines
- [ ] Seam 2 test covers Title-line detection (incl. leading blank lines and frontmatter)
