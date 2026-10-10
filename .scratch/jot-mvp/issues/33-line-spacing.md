# 33: Line spacing

**What to build:** A **Line Spacing** pop-up in Settings > Editor, directly below Font Size, with **Tight**, **Normal** and **Relaxed** (decided 2026-10-10, as in Pages and Notes). Normal is today's spacing and the default. It applies to the editor only, at once, without reopening the panel; the Note List keeps its look. Everything that depends on the line height follows: the paragraph gap between paragraphs (ADR 0004), the line numbers (one per line, on the line's baseline), the current-line band (ticket 29), headings and checklist boxes.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Settings > Editor shows "Line Spacing:" with Tight / Normal / Relaxed below Font Size; Normal by default, looking exactly as before
- [ ] Changing it respaces the open Note at once
- [ ] Line numbers, the current-line band, paragraph gaps, headings and checklists stay aligned at every spacing and font size
- [ ] The setting is remembered across launches
