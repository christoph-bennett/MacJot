# 09: Formatting Toolbar: line formats and list continuation

**What to build:** The toolbar gains a heading menu (H1, H2, H3, Plain) with shortcuts `⌘1`–`⌘3` and `⌘0`, and controls for bullet list, numbered list, checklist and quote. Line formats apply to every line touched by the selection and toggle off if already present. Applying one line format to a line that already has another (e.g. heading on a list item) replaces the existing prefix rather than stacking. Pressing Return in a list item continues the list (next number for numbered lists, unchecked `- [ ]` for checklists); Return on an empty list item ends the list. All implemented as core editing commands.

**Blocked by:** 08

**Status:** ready-for-agent

- [ ] Heading menu and `⌘0`–`⌘3` set the line's heading level
- [ ] Bullet, numbered, checklist and quote toggle on/off for all selected lines
- [ ] Heading on `- item` → `# item` (prefix replaced, not stacked); list on `## x` → `- x`
- [ ] Return in `3. foo` → new line `4. `; in `- [x] done` → `- [ ] `
- [ ] Return on an empty list item removes the marker and ends the list
- [ ] Seam 2 table-driven tests cover each command, prefix replacement, continuation and termination
