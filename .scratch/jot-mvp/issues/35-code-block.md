# 35: Code block button

**What to build:** A **Code Block** button in the Formatting Toolbar, next to Inline Code in the same group (decided 2026-10-10). With lines selected it wraps them in ```` ``` ```` fence lines; with just a cursor on an empty line it inserts an empty block with the cursor inside; with the cursor or selection inside a fenced block it removes that block's fences, toggling like the other buttons. One undo step.

The editor today handles Return inside a fenced block (a single line break, no list continuation) but doesn't style it. This ticket adds that: inside a fenced block (```` ``` ```` or `~~~`) the text is monospaced and no Markdown inside it is formatted; the fence lines are dimmed like other markers.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] The button wraps selected lines in fences, inserts an empty block on an empty line, and removes the fences when used inside a block; ⌘Z undoes it in one step
- [ ] A fenced block shows monospaced, with `**`, `#`, `- [ ]` etc. inside it left unformatted; the fences are dimmed
- [ ] Text after a block is styled normally again; an unclosed fence runs to the end of the Note
- [ ] The button is greyed out for an Outside File, like the rest of the toolbar
