# 31: Outside Files open read-only

**What to build:** Every Markdown file opened with MacJot from Finder that isn't a Note now shows in the Capture Panel as an **Outside File**, read-only (ADR 0007, decided 2026-10-10). This replaces ticket 30's alert ("MacJot only opens notes in your Notes Folder"). Outside Files are files anywhere outside the Notes Folder, files in its subfolders, and `.markdown` files. Notes from the Notes Folder open as in ticket 30.

- **Read-only bar:** a bar between the Formatting Toolbar and the text, in a calm system colour, with an SF Symbol lock and either "Read-only: this file isn't in your Notes Folder." or, for a subfolder, "Read-only: this file is in a subfolder of your Notes Folder." The **Move to Notes Folder** button comes in ticket 32; leave room for it at the right.
- **Editor:** the Formatting Toolbar stays in place, greyed out and inactive. The text can be selected and copied, but typing, pasting and Return do nothing (the system beep). Find works, without Replace. Checklist boxes can't be clicked. No autosave, nothing is ever written to the file.
- **Note List:** the Outside File is the selected top row, like a Draft. It has an SF Symbol lock in the style of the menu bar icon (no emoji), in the secondary text colour, and its folder name as the detail line. It's not part of Search. Its context menu and the editor's `⋯` menu offer Reveal in Finder, Open in Default App and Copy as Markdown; no Move to Trash, and the Delete key does nothing on it.
- **Leaving:** opening another Note, starting a Draft (Capture Hotkey, ⌘N, the + button) or closing the panel forgets the Outside File. It leaves the Note List, and the Search Hotkey's "most recent Note" never picks it.
- **Several files at once:** the first file Finder hands over shows, Note or Outside File; the rest are ignored without an alert. Opening the Outside File already shown just brings the panel to the front.
- **Changes on disk:** changed by another app, the text reloads without asking. Deleted or moved away, the panel shows a Draft, as for a deleted Note. A file that can't be read (not UTF-8, access denied) gets the usual "MacJot couldn't open this file." alert, and nothing changes.
- **Launching:** launching MacJot with an Outside File shows it, also on the very first launch (instead of a Draft).

**Blocked by:** none

**Status:** ready-for-agent

- [ ] A `.md` file from the Desktop opens read-only: bar with the "isn't in your Notes Folder" wording, greyed-out toolbar, typing does nothing, text can be copied
- [ ] A file in a subfolder of the Notes Folder, and a `.markdown` file, open read-only too; the subfolder one with the subfolder wording
- [ ] The Note List shows it as the selected top row with a lock and its folder; Search doesn't find it; its menus have no Move to Trash and Delete does nothing
- [ ] ⌘F finds text in it; Replace isn't offered; checklist boxes don't toggle
- [ ] Opening a Note, starting a Draft or closing the panel forgets it; the file is unchanged on disk
- [ ] Edited elsewhere, the shown text updates; deleted, the panel shows a Draft
- [ ] Opening a Note and an outside file together shows the first one, without an alert; launching MacJot with an Outside File shows it
