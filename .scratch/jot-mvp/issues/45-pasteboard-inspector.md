# 45: Pasteboard and ⌘C inspector

**What to build:** A small developer tool that shows what is on the system pasteboard and what a ⌘C in the apps used daily really does, so that the capture (ticket 49) and the image decisions that follow rest on facts (decided 2026-11-15, spec 0002; widened after a sparring session). It is a separate executable in the repository, built with `swift build` like the search benchmark: not in the MacJot app bundle, not installed by the install script. It avoids Swift macros (no `@Observable`, `#Preview` or SwiftData), because the Command Line Tools can't run their plugins.

It lists every pasteboard item with its types (UTIs), the byte size of each, and a preview: text, RTF, HTML (as source), and images. It refreshes when the clipboard changes. A button presses ⌘C in the frontmost app after a countdown and shows what arrived, how long the pasteboard took to change, and whether it changed more than once. An option holds ⌃⌥ down while it sends the ⌘C, to show what the target app does with leaked modifiers. A line shows the frontmost app's name and its front window's title as the Accessibility API reports them.

It runs against Safari, Chrome, Pages and Terminal, with a selection that is a paragraph, a list and a terminal prompt line. The findings go into this ticket, and ticket 49 is written against them.

**Blocked by:** None (can start immediately). It blocks 49.

**Status:** ready-for-agent

- [ ] `swift build` builds the tool with the sandbox off and no macros; `scripts/bundle.sh` and `scripts/install.sh` don't include it.
- [ ] Copying text in any app shows its item with every type and size within a second, without clicking; copying an image shows the image types, sizes and a preview.
- [ ] The ⌘C button reports the app, the window title, the latency until the first change, the number of changes, and the text read.
- [ ] The held-modifiers option shows whether each of the four apps still copies when ⌃⌥ are held during the ⌘C.
- [ ] It records whether macOS 27 asks before a program reads the pasteboard, and what each app puts there for text.
- [ ] Findings, written into this ticket under "Findings": latency per app, window titles per app (Chrome with its profile, Safari, Pages, Terminal), the modifier result, the pasteboard prompt result, and anything that changes ticket 49 or 46.
