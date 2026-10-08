# Jot — MVP Spec

Working title "Jot" (bundle ID `com.onethingwell.jot`). A menu-bar app for capturing quick notes via a global hotkey and keeping them as plain Markdown files. Vocabulary: see [GLOSSARY.md](./GLOSSARY.md). Key decisions: [docs/adr/](./docs/adr/).

## Platform

- Swift, AppKit-first (`NSStatusItem`, `NSPanel`, `NSTextView`/TextKit); SwiftUI only for secondary views (Settings) via `NSHostingView`. ([ADR 0002](./docs/adr/0002-native-appkit.md))
- macOS 14+. Unsandboxed, Developer-ID-notarisable; avoid choices that would block a sandboxed build later.
- Menu-bar only (`LSUIElement`), no Dock icon.

## 1. Menu bar & system presence

- Status item menu: **New Note**, **Show Notes**, **Settings…**, **Quit**.
- Launch at login via `SMAppService`, on by default, toggle in Settings.

**Acceptance**
- App never shows in Dock or ⌘-Tab.
- Toggling launch-at-login takes effect without restart.

## 2. Hotkeys

- **Capture Hotkey**, default `⌃⌥N`; **Search Hotkey**, default `⌃⌥F`. Both reconfigurable in Settings. Registered via Carbon `RegisterEventHotKey` (no Accessibility permission).
- State matrix:

| Panel state | Capture Hotkey | Search Hotkey |
|---|---|---|
| Hidden | Show panel with a new Draft | Show panel, Note List open, search focused |
| Visible, not key | Bring to front, keep content | Bring to front, focus search |
| Key, same mode | Hide | Hide |
| Key, other mode | Switch to new Draft | Switch to search |

**Acceptance**
- Hotkeys work from any app, including full-screen apps.
- Changing a hotkey in Settings re-registers immediately; conflicting/unavailable combos are reported.

## 3. Capture Panel

- Floating `NSPanel` above normal windows, appears on the active Space.
- Size **and** position remembered. If the remembered position is on a disconnected screen, centre on the current screen. Settings has one **Reset Panel Size & Position** button.
- Layout: editor + collapsible Note List sidebar (`⌘\`). Sidebar collapsed when opened via Capture Hotkey, open via Search Hotkey.
- `⌘N` starts a new Draft from anywhere in the panel.
- `Esc`: clears search if non-empty, otherwise closes the panel. Closing never prompts; the Note is already saved.
- Losing focus while showing only a Draft hides the panel.
- Cursor position remembered per Note (in-app state, not in the file).

## 4. Draft & lifecycle

- A new Note starts as a **Draft**: no file exists until the first non-whitespace character is typed.
- Closing/leaving an empty Draft creates nothing.
- A saved Note whose content becomes empty/whitespace is moved to the system Trash when the user leaves it.

## 5. Editor

- Styled Markdown: syntax characters stay in the text but are dimmed; formatting is rendered (bold, italic, strikethrough, headings, lists, quotes, inline code, links).
- Fonts: SF Pro for prose; SF Mono for inline code and syntax markers. Font size configurable.
- The **Title** (first non-blank line) is always styled prominently, regardless of Markdown.
- Clickable task checkboxes: clicking `[ ]`/`[x]` toggles it in the text.
- List continuation: Return in a list item continues the list (bullet, numbered with increment, checklist unchecked); Return on an empty item ends the list.
- Out of scope: underline, code blocks, tables, images, horizontal rules, highlight.

## 6. Formatting Toolbar

- Controls: **Bold**, *Italic*, ~~Strikethrough~~ · Heading menu (H1, H2, H3, Plain) · Bullet list, Numbered list, Checklist · Quote, Inline code, Link.
- Each control toggles: applies syntax if absent, removes it if present (selection or current line/word).
- Shortcuts: `⌘B`, `⌘I`, `⌘⇧X`, `⌘1`/`⌘2`/`⌘3` (and `⌘0` plain), plus menu equivalents for the rest.

**Acceptance**
- Toggling twice returns the text to its original state.
- Applying a heading to a list item or quote replaces the line prefix rather than stacking markers.

## 7. Files & naming

- Files are the only source of truth; no frontmatter written. Existing frontmatter in a file is preserved and ignored for the Title. ([ADR 0001](./docs/adr/0001-markdown-files-are-source-of-truth.md))
- One **Notes Folder**, top-level `.md` files only. Default `~/Documents/Jot/`, created silently on first launch.
- Filename = slug of the Title ([ADR 0003](./docs/adr/0003-filenames-follow-title.md)):
  - strip leading Markdown (`#`, `- [ ]`, `>`, `**` …)
  - transliterate to ASCII (`Über` → `uber`, `ß` → `ss`), drop remaining non-ASCII
  - lowercase; non-alphanumerics → `-`, collapse repeats, trim
  - cap at 60 chars on a word boundary
  - empty result → `untitled`
  - collision → `-2`, `-3`, …
- **Date Prefix** setting (off by default): `yyyy-mm-dd-` of creation day, applies to new Notes only; never changed by later renames.
- Rename-on-rest: when the Title changes, the file is renamed when the user leaves the Note (panel close, switching Notes, ⌘N), not while typing.
- Created date: from Date Prefix if present, else filesystem creation date.

**Acceptance (unit-testable slug cases)**
- `# Über Änderungen!` → `uber-anderungen.md`
- `- [ ] Call Anna` → `call-anna.md`
- `🎉🎉` → `untitled.md`
- Two Notes titled `Meeting` → `meeting.md`, `meeting-2.md`
- Date Prefix on, created 2026-10-08, retitled → `2026-10-08-<new-slug>.md`

## 8. Saving & external changes

- Autosave ~0.5 s after typing stops, and on leaving a Note / closing the panel / quitting.
- Atomic writes; saves serialised per file; a save loop ensures text typed during a save is persisted.
- Watch the Notes Folder (FSEvents). On external change to the open Note: reload if no unsaved edits; otherwise local version wins. Notes added/removed/renamed externally update the Note List.

## 9. Note List & search

- Sorted by last modified, newest first.
- Row: Title, date, one-line preview (match snippet while searching).
- Date display: relative ("2h", "Mon") by default; Settings toggle to show absolute dates in the system short format.
- Search: live, case- and diacritic-insensitive substring match over Title and body, in memory. Arrow keys move selection, Return opens.
- Context menu (and `⋯` in editor): **Reveal in Finder**, **Open in Default App**, **Copy as Markdown**, **Move to Trash** (system Trash, no confirmation).

## 10. Settings

- Notes Folder (picker). On change: switch to the new folder; show a dialog explaining existing Notes must be moved manually, with a **Show Old Folder** button.
- Capture Hotkey, Search Hotkey.
- Launch at login.
- Font size.
- Date Prefix for new Notes.
- Relative dates in Note List.
- Reset Panel Size & Position.
- Appearance follows system light/dark.

## 11. First launch

- No onboarding. Create the default Notes Folder, show a brief hint near the status item listing both hotkeys, open a Draft.

## Milestones

1. **Skeleton** — Xcode project, `LSUIElement`, status item + menu, Settings window shell, launch at login.
2. **Hotkeys & panel** — both hotkeys, `NSPanel` behaviour, state matrix, size/position memory.
3. **Files** — Notes Folder, slug/naming (with unit tests), Draft lifecycle, autosave, rename-on-rest, Trash.
4. **Editor styling** — Markdown highlighting, Title styling, list continuation, clickable checkboxes.
5. **Formatting Toolbar** — toggle logic (unit-tested on plain strings) + shortcuts.
6. **Note List & search** — in-memory index, sidebar, keyboard navigation, context actions.
7. **Watching** — FSEvents reconciliation.
8. **Settings complete & first launch** — remaining settings, folder-change dialog, first-run hint.

## Later (not MVP)

Reopen-last-Note hotkey · subfolders & per-folder hotkeys · pinned stickies · image paste · slash commands & templates · highlight · code blocks & tables · SQLite FTS5 Search Index · append-selection Clips · copy as rich text.

## Not planned

AI features · dictation · encryption · Git sync · Apple Notes import · streaks/stats · analytics · i18n · custom themes.
