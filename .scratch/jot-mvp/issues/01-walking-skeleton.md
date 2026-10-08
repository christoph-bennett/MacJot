# 01: Walking skeleton: write a Note from the menu bar

**What to build:** Jot runs as a menu-bar-only app (no Dock icon, not in ⌘-Tab) with a status item menu offering **New Note** and **Quit**, and launches at login by default. New Note opens a basic panel with a plain text editor showing a fresh Draft. As soon as the user types non-whitespace text, a Note file appears in the default Notes Folder (`~/Documents/Jot/`, created silently if missing), named with a simple slug of the Title. The Note is autosaved ~0.5 s after typing stops and flushed when the panel closes or the app quits; closing never prompts. Leaving an untouched Draft creates no file. This ticket also establishes the project structure: an Xcode app target (AppKit) plus a pure-Swift core package with a test target, with the **Notes Folder** facade as the core's entry point (injected folder location and clock; saves triggered by explicit flush calls from the shell). See spec 0001 and ADRs 0001–0003.

**Blocked by:** None (can start immediately).

**Status:** done

- [ ] App builds and runs on macOS 14+; no Dock icon, not in ⌘-Tab (builds and launches; Dock/⌘-Tab not yet checked by eye)
- [ ] Status item menu shows New Note and Quit
- [ ] Launch at login is registered on first run
- [ ] New Note opens a panel with the cursor in an empty Draft
- [x] Typing creates exactly one `.md` file in `~/Documents/Jot/` named after the Title (lowercase, spaces → `-`)
- [ ] Text is persisted ~0.5 s after typing stops, on panel close and on quit; no save prompt ever appears
- [x] Closing an untouched Draft leaves no file
- [x] Text typed while a save is in flight is persisted (flush loops until persisted text equals latest text); writes are atomic
- [x] Core package has no AppKit dependency
- [x] Seam 1 tests (Notes Folder over a real temp directory; clock injection deferred to ticket 04, its first consumer) cover: Draft creates no file, first content materialises a file, flush persists latest text
