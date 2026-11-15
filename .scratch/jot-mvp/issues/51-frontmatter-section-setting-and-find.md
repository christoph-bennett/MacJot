# 51: Frontmatter Section: auto-expand setting and Find

**What to build:** The rest of the Frontmatter Section (decided 2026-11-15, spec 0002; split from ticket 44 after a sparring session). Settings > Editor gets "Expand frontmatter when a Note opens", off by default: with it on, a Note with frontmatter opens expanded instead of collapsed. A manual toggle (chevron or ⌥⌘P) still lasts only while the Note is open and is stored nowhere. Find (⌘F) that matches inside a collapsed section expands it, so a match is never hidden.

**Blocked by:** 44 (Frontmatter Section: display and toggle).

**Status:** ready-for-agent

- [ ] The setting is off by default; with it on, Notes with frontmatter open expanded, and the choice survives a restart; Notes without frontmatter are unaffected.
- [ ] A Find match inside the collapsed section expands it and shows the match; clearing Find doesn't collapse it again.
- [ ] The offscreen gutter harness shows no overlapping line numbers while Find expands and collapsing follows (same check as ticket 44).
- [ ] Manual check in light and dark.
