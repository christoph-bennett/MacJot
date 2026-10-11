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

Picked from Later 2026-10-10 (second round):

- **Line spacing**: Tight / Normal / Relaxed below Font Size. → ticket 33
- **Show invisible characters**: `·` `→` `¬` `¶`, in Settings > Editor and View > Show Invisibles (⌥⌘I). → ticket 34
- **Code block button**, with fenced blocks styled monospaced. → ticket 35
- **Horizontal line** in the heading pop-up, drawn as a thin rule. → ticket 36
- **Search by several words**, in any order, `"quotes"` for a phrase; instead of an SQLite index. → ticket 37
- **Setting: custom Date Prefix format**, configured Hazel-style with tokens (Year, Month, Day, Separator) in a popover from Settings > General; the prefix is found by the Title, never parsed (ADR 0009, designed 2026-10-11). → tickets 38 and 39

Earlier:

- **Rename to MacJot** → ticket 17, ADR 0006 (decided 2026-10-09; replaces the Inbox item "Final app name and bundle ID"). Released on GitHub only, so Apple's rule against "Mac" in third-party names is an accepted risk. User-facing texts, app bundle, executable and process, bundle ID, Application Support folder, scripts and `SERVICES.md`; Swift module and type names stay. New installs default to `~/Documents/MacJot`; an existing Notes Folder is never moved or renamed.
- **Settings always opens on General** when its window opens, instead of the last pane → ticket 18.
- **HIG audit of Settings and the Note List** → ticket 19, fixes in tickets 20 to 22: layout, spacing, typography. An audit first, the user approves which findings get fixed.

- **Line numbers in the editor**, on by default, with a Settings option to turn them off → ticket 16.

## Later

- **Install Xcode.** Needed for notarised distribution; also removes the deprecated `--build-system native` workaround in `scripts/test.sh` and the CLT linker warnings. Revisit before a public release.
- Editor support for tables and images.
- Slash commands and templates; wiki-links (renaming would have to update links, see ADR 0003).
- Append the selection from any app to a Note ("Clips").

## Not planned

Decided 2026-10-10 (second round of Later):

- **Subfolders, notebooks, per-folder hotkeys**: a deliberate absence; one flat Notes Folder, found again with Search (ADR 0008).
- **Pinned sticky windows; several editor windows at once**: MacJot is one panel showing one Note, summoned and dismissed; separate windows would make it a document-based app.
- **Settings in a config file**: no reason yet to keep one beside the Settings window (hand edits, dotfiles, scripts); revisit if one comes up.
- **`==highlight==`**: not standard Markdown; most other tools show the `==` literally.
- **SQLite FTS5 Search Index**: substring search is the wanted behaviour (ticket 37 adds several words), and it's instant at this size; ADR 0001 would still apply.
- **Copy a Note as rich text**: Copy as Markdown covers it; faithful rich text for lists and headings needs a converter of its own.
- **Conflict-resolution UI for concurrent external edits**: local unsaved edits win; a conflict needs two editors on one Note at the same moment.

Earlier:

- **Editing Outside Files in place**: Notes live in one folder, and moving a file there keeps the Note List, Search, renaming and trashing consistent; Outside Files are read-only until moved (ADR 0007, decided 2026-10-10).
- **App Store / sandboxed build**: MacJot is released on GitHub only (ADR 0006; "Mac" in the name wouldn't pass review), and a sandbox would restrict access to the Notes Folder (decided 2026-10-10).
- **Keep macOS inline predictions in the editor**: they insert line breaks past the Return handling (ADR 0004); catching those reliably is a lot of fragile work for little gain (decided 2026-10-10).
- **Hotkey to reopen the last Note**: the Search Hotkey already opens the most recently changed Note, and Return continues writing in it (decided 2026-10-10).
- **Underline**: Markdown has no syntax for it; `<u>` would put HTML in the files.
- **AI features, dictation, encryption, Git sync, Apple Notes import**: outside the "quick plain-Markdown capture" scope (decided when comparing with Stik).
- **Streaks/stats, analytics, localisation, custom themes and opacity**: same reason.
- **Moving Notes when the Notes Folder changes**: the user moves them; MacJot only shows a hint (Q30).
- **Renaming existing files when the Date Prefix setting changes**: the setting applies to new Notes only (Q22).
