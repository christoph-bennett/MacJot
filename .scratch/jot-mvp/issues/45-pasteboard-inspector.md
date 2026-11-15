# 45: Pasteboard inspector

**What to build:** A small developer tool that shows what is on the system pasteboard, so the image decisions after Clips rest on facts (decided 2026-11-15, spec 0002). It is a separate executable in the repository, built with `swift build` like the search benchmark: not in the MacJot app bundle, not installed by the install script. It avoids Swift macros (no `@Observable`, `#Preview` or SwiftData), because the Command Line Tools can't run their plugins.

It lists every pasteboard item with its types (UTIs), the byte size of each, and a preview: text, RTF, HTML (as source), and images. It refreshes when the clipboard changes. A button presses ⌘C in the frontmost app after a short countdown and shows what arrived, so that you can see what the Clip sequence would read from any app. Findings about a browser, Mail and a PDF viewer are recorded in the ticket afterwards.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `swift build` builds the tool with the sandbox off and no macros; `scripts/bundle.sh` and `scripts/install.sh` don't include it.
- [ ] Copying text in any app shows its item with every type and size within a second, without clicking.
- [ ] Copying an image (a screenshot, an image from Safari, a file's thumbnail) shows the image types, sizes and a visible preview.
- [ ] The ⌘C button copies the selection of the frontmost app after the countdown and shows the result; it leaves the previous clipboard restored or says it didn't.
- [ ] Manual check with a browser, Mail and a PDF viewer; what each puts on the pasteboard is written into this ticket under "Findings", as input for the image grilling.
