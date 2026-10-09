# Backlog

Ideas and requirements not yet built. New items go to **Inbox**; when triaged they move to **MVP** (and become a ticket in `.scratch/jot-mvp/issues/`), **Later**, or **Not planned** (with the reason). Vocabulary: [GLOSSARY.md](./GLOSSARY.md). MVP scope: [spec 0001](./docs/specs/0001-mvp.md).

## Inbox

- **Keep macOS inline predictions in the editor.** They are off because Return with a prediction showing bypassed the paragraph handling (ADR 0004). Would need handling line breaks the input system inserts itself.
- **Register Jot on the services dashboard and in `~/services/SERVICES.md`**, including the Recovery Copy location (`~/Library/Application Support/Jot/recovery.md`), once Jot runs from a stable path like `~/Applications/Jot.app`.
- **Install Xcode.** Needed for notarised distribution; also removes the deprecated `--build-system native` workaround in `scripts/test.sh` and the CLT linker warnings.
- **Hint while a Note is empty**: a dimmed placeholder in the editor such as "Leave this note empty to move it to the Trash", so emptying a Note isn't a surprise. Chosen over a confirmation dialog: trashing happens on leave (panel close, switching Notes, quit), where a dialog would block or arrive in a closing panel, and nothing is lost (⌘Z while open, Finder's Trash afterwards).
- **Trash an emptied Note with its full contents, even when deleted slowly.** The Trash gets the last autosaved version; deleting with pauses autosaves shrinking versions, so in the worst case only a few characters end up there (select-all + Delete is fine). Fix: trash the longest version saved since the Note was opened, or the version it was opened with.
- **Emptied paragraph grows a few pixels.** Return, type a new paragraph, then Backspace until it's empty: that line gets taller (the cursor looks bigger too) and pushes everything below it down a little. Reported 2026-10-08 after the switch to TextKit 1; minor.
- **Setting: word wrap on/off** (on by default). Off: long lines run on and the editor scrolls horizontally, useful for tables and code. On TextKit 1 this is `isHorizontallyResizable`, the text container not tracking the view's width, and a horizontal scroller. Seen in STTextView (github.com/krzyzanowskim/STTextView, GPL: ideas only, no code).
- **Find and replace in the editor** (⌘F): the standard macOS find bar, which NSTextView offers on TextKit 1 (`usesFindBar`, incremental search). The panel's shortcuts go through `CapturePanel.sendEvent`, so ⌘F, ⌘G and ⌘⇧G must be added there.
- **Highlight the current line**: a faint background behind the line with the cursor, following light/dark; maybe a Settings toggle.
- **Setting: line height** (spacing between lines), next to font size; the paragraph gap and line numbers have to follow it.
- **Show invisible characters**: spaces, tabs and line breaks as faint symbols, e.g. to check Markdown line breaks; toggle in Settings or the View menu.
- **Final app name and bundle ID** before the first public release ("Jot" and `com.onethingwell.jot` are working names; the bundle ID can't change afterwards without losing user settings and permissions).
- **Setting: custom Date Prefix format**, e.g. `20261009-` or `2026-10-09_` instead of the fixed `2026-10-09-`; next to the Date Prefix checkbox in Settings > General, with the live example showing the result. Jot also reads the prefix back (`DatePrefix.of`, `DatePrefix.day(of:)`) to keep it on rename and to date the Note List, so recognising Notes named with an earlier format has to keep working; the format may need limits (must contain year, month and day, only filename-safe characters).

## MVP

- **Line numbers in the editor**, on by default, with a Settings option to turn them off → ticket 16.

## Later

- Toolbar and editor support for code blocks, tables, images, horizontal rules and `==highlight==`.
- Subfolders/notebooks and per-folder hotkeys.
- Hotkey to reopen the last Note.
- Pinned sticky windows; multiple editor windows at once.
- Slash commands and templates; wiki-links.
- SQLite FTS5 Search Index (ADR 0001: always rebuildable from the files).
- Append the selection from any app to a Note ("Clips").
- Copy a Note as rich text.
- Conflict-resolution UI for concurrent external edits (MVP: local unsaved edits win).
- App Store / sandboxed build.
- **Open `.md` files from Finder in Jot** ("Open With", or as the default app for Markdown). Open question: a file outside the Notes Folder is edited in place in the Capture Panel, or copied into the Notes Folder? In place fits ADR 0001; rename-on-leave and the Note List would then need to handle files outside the folder.

## Not planned

- **Underline**: Markdown has no syntax for it; `<u>` would put HTML in the files.
- **AI features, dictation, encryption, Git sync, Apple Notes import**: outside the "quick plain-Markdown capture" scope (decided when comparing with Stik).
- **Streaks/stats, analytics, localisation, custom themes and opacity**: same reason.
- **Moving Notes when the Notes Folder changes**: the user moves them; Jot only shows a hint (Q30).
- **Renaming existing files when the Date Prefix setting changes**: the setting applies to new Notes only (Q22).
