# Backlog

Ideas and requirements not yet built. New items go to **Inbox**; when triaged they move to **MVP** (and become a ticket in `.scratch/jot-mvp/issues/`), **Later**, or **Not planned** (with the reason). Vocabulary: [GLOSSARY.md](./GLOSSARY.md). MVP scope: [spec 0001](./docs/specs/0001-mvp.md).

## Inbox

## MVP

Triaged 2026-10-10 (next batch: for daily use, no public release yet):

- **Find and replace in the editor** (⌘F): the standard macOS find bar, which NSTextView offers on TextKit 1 (`usesFindBar`, incremental search). The panel's shortcuts go through `CapturePanel.sendEvent`, so ⌘F, ⌘G and ⌘⇧G must be added there. → ticket 24
- **Hint while a Note is empty**: a dimmed placeholder in the editor such as "Leave this note empty to move it to the Trash", so emptying a Note isn't a surprise. Chosen over a confirmation dialog: trashing happens on leave (panel close, switching Notes, quit), where a dialog would block or arrive in a closing panel, and nothing is lost (⌘Z while open, Finder's Trash afterwards). → ticket 25
- **Trash an emptied Note with its full contents, even when deleted slowly.** The Trash gets the last autosaved version; deleting with pauses autosaves shrinking versions, so in the worst case only a few characters end up there (select-all + Delete is fine). Fix: trash the longest version saved since the Note was opened, or the version it was opened with. → ticket 26 (decided: the longest)
- **`scripts/install.sh`: MacJot often doesn't start after installing** (`open` fails with error -600 although the script waits for the old process to quit). Found 2026-10-09. → ticket 27

Picked from Later 2026-10-10:

- **Setting: word wrap on/off** (on by default). Off: long lines run on and the editor scrolls horizontally, useful for tables and code. On TextKit 1 this is `isHorizontallyResizable`, the text container not tracking the view's width, and a horizontal scroller. Seen in STTextView (github.com/krzyzanowskim/STTextView, GPL: ideas only, no code). → ticket 28
- **Open `.md` files from Finder in MacJot** → ticket 30 (decided 2026-10-10: Open With only, never the default app; files in the Notes Folder open, others get an alert).
- **Highlight the current line**: a faint background behind the line with the cursor, following light/dark; with a toggle in Settings > Editor. → ticket 29

Decided 2026-10-10, after trying ticket 30's alert:

- **Outside Files open read-only**, with a **Move to Notes Folder** button, instead of the alert for files outside the Notes Folder (ADR 0007). → tickets 31 and 32

Earlier:

- **Rename to MacJot** → ticket 17, ADR 0006 (decided 2026-10-09; replaces the Inbox item "Final app name and bundle ID"). Released on GitHub only, so Apple's rule against "Mac" in third-party names is an accepted risk. User-facing texts, app bundle, executable and process, bundle ID, Application Support folder, scripts and `SERVICES.md`; Swift module and type names stay. New installs default to `~/Documents/MacJot`; an existing Notes Folder is never moved or renamed.
- **Settings always opens on General** when its window opens, instead of the last pane → ticket 18.
- **HIG audit of Settings and the Note List** → ticket 19, fixes in tickets 20 to 22: layout, spacing, typography. An audit first, the user approves which findings get fixed.

- **Line numbers in the editor**, on by default, with a Settings option to turn them off → ticket 16.

## Later

- **Setting: line height** (spacing between lines), next to font size; the paragraph gap and line numbers have to follow it.
- **Show invisible characters**: spaces, tabs and line breaks as faint symbols, e.g. to check Markdown line breaks; toggle in Settings or the View menu.
- **Setting: custom Date Prefix format**, e.g. `20261009-` or `2026-10-09_` instead of the fixed `2026-10-09-`; next to the Date Prefix checkbox in Settings > General, with the live example showing the result. MacJot also reads the prefix back (`DatePrefix.of`, `DatePrefix.day(of:)`) to keep it on rename and to date the Note List, so recognising Notes named with an earlier format has to keep working; the format may need limits (must contain year, month and day, only filename-safe characters).
- **Settings in a config file** at `~/.macjot/config.json` instead of UserDefaults. Postponed 2026-10-09 before deciding why (hand edits, dotfiles, scripts), which settings go in it (settings only, or also state like window frames and cursor positions) and where it lives (`~/.macjot/` or `~/.config/macjot/`). Hotkeys are stored by KeyboardShortcuts itself; the Notes Folder has a binary bookmark next to its path.
- **Install Xcode.** Needed for notarised distribution; also removes the deprecated `--build-system native` workaround in `scripts/test.sh` and the CLT linker warnings.
- Toolbar and editor support for code blocks, tables, images, horizontal rules and `==highlight==`.
- Subfolders/notebooks and per-folder hotkeys.
- Pinned sticky windows; multiple editor windows at once.
- Slash commands and templates; wiki-links.
- SQLite FTS5 Search Index (ADR 0001: always rebuildable from the files).
- Append the selection from any app to a Note ("Clips").
- Copy a Note as rich text.
- Conflict-resolution UI for concurrent external edits (MVP: local unsaved edits win).

## Not planned

- **Editing Outside Files in place**: Notes live in one folder, and moving a file there keeps the Note List, Search, renaming and trashing consistent; Outside Files are read-only until moved (ADR 0007, decided 2026-10-10).
- **App Store / sandboxed build**: MacJot is released on GitHub only (ADR 0006; "Mac" in the name wouldn't pass review), and a sandbox would restrict access to the Notes Folder (decided 2026-10-10).
- **Keep macOS inline predictions in the editor**: they insert line breaks past the Return handling (ADR 0004); catching those reliably is a lot of fragile work for little gain (decided 2026-10-10).
- **Hotkey to reopen the last Note**: the Search Hotkey already opens the most recently changed Note, and Return continues writing in it (decided 2026-10-10).
- **Underline**: Markdown has no syntax for it; `<u>` would put HTML in the files.
- **AI features, dictation, encryption, Git sync, Apple Notes import**: outside the "quick plain-Markdown capture" scope (decided when comparing with Stik).
- **Streaks/stats, analytics, localisation, custom themes and opacity**: same reason.
- **Moving Notes when the Notes Folder changes**: the user moves them; MacJot only shows a hint (Q30).
- **Renaming existing files when the Date Prefix setting changes**: the setting applies to new Notes only (Q22).
