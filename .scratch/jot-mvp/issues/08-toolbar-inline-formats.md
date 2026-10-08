# 08: Formatting Toolbar: inline formats

**What to build:** The Capture Panel shows the Formatting Toolbar with **Bold**, *Italic*, ~~Strikethrough~~, inline code and link controls. Each applies its syntax around the selection (or current word when there's no selection) and removes it if already present, so applying twice returns the original text. Shortcuts: `⌘B`, `⌘I`, `⌘⇧X`. Link inserts `[text](url)` with the URL part selected for typing. The logic lives in the core as editing commands: pure functions over (text, selection) → (text, selection); the toolbar and shortcuts only delegate to them.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Toolbar shows B, I, S, inline code, link
- [ ] Each control applies to the selection, or the word at the cursor when nothing is selected
- [ ] Applying a format twice restores the original text and selection
- [ ] `⌘B`, `⌘I`, `⌘⇧X` match their toolbar buttons
- [ ] Link leaves the URL placeholder selected
- [ ] Undo reverts a toolbar action in one step
- [ ] Seam 2 table-driven tests cover every inline command and its inverse
