# 28: Word wrap on/off

**What to build:** A **Wrap lines** checkbox in Settings > Editor, below Line Numbers, on by default (decided 2026-10-10); no menu item or shortcut, like line numbers. On: as today, lines wrap at the editor's width. Off: long lines run past the right edge and the editor scrolls horizontally; the horizontal scroll bar appears only when a line is too wide (system scroller behaviour), and while typing at the end of a long line the view follows the cursor. Line numbers stay one per line, paragraph gaps and the empty-Note hint (ticket 25) are unaffected. On TextKit 1: `isHorizontallyResizable`, a text container that doesn't track the view's width, `hasHorizontalScroller`. Takes effect immediately, without reopening the panel. Ideas seen in STTextView (GPL: ideas only, no code).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Settings > Editor shows "Wrap lines", checked by default, below Line Numbers
- [ ] Unchecked: a long line stays one line and the editor scrolls sideways; short Notes show no horizontal scroll bar
- [ ] Typing at the end of a long line keeps the cursor in view
- [ ] Line numbers, find (⌘F) and the current-line highlight (ticket 29, if done) still line up with wrapping off
- [ ] Checking it again wraps the lines at once
