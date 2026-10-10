# 30: MacJot opens `.md` files from its Notes Folder

**What to build:** macOS knows MacJot can open Markdown files (decided 2026-10-10): `Info.plist` declares `.md` (`net.daringfireball.markdown`) as a document type MacJot handles, with a rank that never makes it the default app (e.g. `LSHandlerRank` Alternate), so it appears in Finder's Open With and in Get Info > Open with; the user makes it the default there if they want. Choosing MacJot for a file **inside the Notes Folder** opens it in the Capture Panel as if picked in the Note List (the previous Note is left as usual; the Note List stays open or collapsed as it was; launching MacJot this way opens the file, not a new Draft). A file **anywhere else** gets a short MacJot alert: "MacJot only opens notes in your Notes Folder (~/Documents/MacJot)." with the actual folder; nothing is opened, so macOS never shows its own "cannot open files in the Markdown format" error. Editing files outside the folder stays in BACKLOG (Later). Delegate: `application(_:open:)`; a subfolder of the Notes Folder isn't inside it (Notes are its top-level `.md` files).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Finder > a `.md` file > Open With lists MacJot; the default app for Markdown doesn't change
- [ ] Opening a Note from the Notes Folder with MacJot shows it in the Capture Panel, MacJot running or not
- [ ] Opening a `.md` file from elsewhere (or a subfolder) shows the alert naming the Notes Folder, and changes nothing
- [ ] Several files at once: Notes Folder files open the first one; outside ones get one alert
