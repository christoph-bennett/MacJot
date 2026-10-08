# 09: Formatting Toolbar: line formats and list continuation

**What to build:** The toolbar gains a heading menu (H1, H2, H3, Plain) with shortcuts `⌘1`–`⌘3` and `⌘0`, and controls for bullet list, numbered list, checklist and quote. Line formats apply to every line touched by the selection and toggle off if already present. Applying one line format to a line that already has another (e.g. heading on a list item) replaces the existing prefix rather than stacking. Pressing Return in a list item continues the list (next number for numbered lists, unchecked `- [ ]` for checklists); Return on an empty list item ends the list. All implemented as core editing commands.

**Blocked by:** 08

**Status:** done

- [x] Heading menu and `⌘0`–`⌘3` set the line's heading level
- [x] Bullet, numbered, checklist and quote toggle on/off for all selected lines
- [x] Heading on `- item` → `# item` (prefix replaced, not stacked); list on `## x` → `- x`
- [x] Return in `3. foo` → new line `4. `; in `- [x] done` → `- [ ] `
- [x] Return on an empty list item removes the marker and ends the list
- [x] Seam 2 table-driven tests cover each command, prefix replacement, continuation and termination

**Changed after the user tried it:** making a list from paragraphs drops the blank lines between them (a tight list), and removing a list makes its items paragraphs again. ⌘0–⌘3 are the heading menu's key equivalents (a panel key equivalent reaches its controls before `CapturePanel.sendEvent`), applied only while the editor has focus.

**Editor fixes made along the way:** the cursor never rests on a paragraph gap (↑/↓ skip it keeping the column, ←/→ and clicks step off it); Backspace right after a paragraph break removes the whole break; horizontal rules are styled as syntax, not as list items; the editor runs on TextKit 1, because TextKit 2 placed an empty last line too low after Return at the end of a Note.
