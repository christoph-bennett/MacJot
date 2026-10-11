# Jot MVP tickets

One file per ticket, each with its full description and acceptance criteria. This index lists them at a glance; update its Status column whenever a ticket's status changes. Spec: [docs/specs/0001-mvp.md](../../../docs/specs/0001-mvp.md). Not yet ticketed: [BACKLOG.md](../../../BACKLOG.md).

| # | Ticket | Blocked by | Status |
|---|---|---|---|
| 01 | [Walking skeleton: write a Note from the menu bar](01-walking-skeleton.md) | none | done |
| 02 | [Capture Hotkey and floating panel](02-capture-hotkey-and-panel.md) | 01 | done |
| 03 | [Full filename rules, Title-finished creation and rename-on-leave](03-filename-rules-and-renaming.md) | 01 | done |
| 04 | [Settings window and Date Prefix](04-settings-window-and-date-prefix.md) | 03 | done |
| 05 | [Note List: browse and reopen Notes](05-note-list.md) | 01 | done |
| 06 | [Search and the Search Hotkey](06-search-and-search-hotkey.md) | 02, 05 | done |
| 07 | [Styled Markdown editor](07-styled-markdown-editor.md) | 01 | done |
| 08 | [Formatting Toolbar: inline formats](08-toolbar-inline-formats.md) | 01 | done |
| 09 | [Formatting Toolbar: line formats and list continuation](09-toolbar-line-formats-and-lists.md) | 08 | done |
| 10 | [Clickable checkboxes](10-clickable-checkboxes.md) | 07, 09 | done |
| 11 | [External changes](11-external-changes.md) | 05 | done |
| 12 | [Choose the Notes Folder](12-choose-notes-folder.md) | 04, 05 | done |
| 13 | [Hotkey settings](13-hotkey-settings.md) | 04, 06 | done |
| 14 | [Remaining settings and first launch](14-remaining-settings-and-first-launch.md) | 04, 05, 06, 07, 15 | done |
| 15 | [Settings panes](15-settings-panes.md) | 12 | done |
| 16 | [Line numbers](16-line-numbers.md) | 07, 14 | done |
| 17 | [Rename to MacJot](17-rename-to-macjot.md) | 18 | done |
| 18 | [Settings opens on General](18-settings-opens-on-general.md) | none | done |
| 19 | [HIG audit of Settings and the Note List](19-hig-audit.md) | 17 | done |
| 20 | [Settings spacing](20-settings-spacing.md) | 19 | done |
| 21 | [Note List layout](21-note-list-layout.md) | 19 | done |
| 22 | [Note List empty states](22-note-list-empty-states.md) | 19 | done |
| 23 | [Paragraph gaps: no number, no height](23-line-numbers-skip-paragraph-gaps.md) | 16 | done |
| 24 | [Find and replace in the open Note](24-find-and-replace.md) | none | done |
| 25 | [Hint while a Note is empty](25-empty-note-hint.md) | 26 | done |
| 26 | [Trash an emptied Note with its full contents](26-trash-full-contents.md) | none | done |
| 27 | [`install.sh` starts MacJot reliably](27-install-script-starts-macjot.md) | none | done |
| 28 | [Word wrap on/off](28-word-wrap-setting.md) | none | done |
| 29 | [Highlight the current line](29-highlight-current-line.md) | none | done |
| 30 | [MacJot opens `.md` files from its Notes Folder](30-open-md-files.md) | none | done |
| 31 | [Outside Files open read-only](31-outside-files-read-only.md) | none | done |
| 32 | [Move to Notes Folder](32-move-to-notes-folder.md) | 31 | done |
| 33 | [Line spacing](33-line-spacing.md) | none | done |
| 34 | [Show invisible characters](34-show-invisibles.md) | none | done |
| 35 | [Code block button](35-code-block.md) | none | done |
| 36 | [Horizontal line](36-horizontal-line.md) | none | done |
| 37 | [Search by several words](37-search-several-words.md) | none | done |

Statuses: `ready-for-agent` (can be picked up once its blockers are done) → `implemented, awaiting manual UI check` → `done` (checked by hand).

Planned order for the rest: none ticketed. The custom Date Prefix format (BACKLOG MVP) gets its own design session before it's ticketed.
