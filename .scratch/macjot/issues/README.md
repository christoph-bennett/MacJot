# MacJot tickets (after the MVP)

One file per ticket, each with its full description and acceptance criteria. This index lists them at a glance; update its Status column whenever a ticket's status changes. The numbering continues from the MVP tickets (1 to 42, [../../jot-mvp/issues/](../../jot-mvp/issues/README.md)); the MVP is complete (git tag `mvp`). Spec: [docs/specs/0002-clips.md](../../../docs/specs/0002-clips.md). Not yet ticketed: [BACKLOG.md](../../../BACKLOG.md).

| # | Ticket | Blocked by | Status |
|---|---|---|---|
| 43 | [Sign the app with the Apple Development identity](43-sign-with-development-identity.md) | none | done |
| 44 | [Frontmatter Section: display and toggle](44-frontmatter-section.md) | none | done |
| 45 | [Pasteboard and ⌘C inspector](45-pasteboard-inspector.md) | none | done |
| 46 | [Clip Hotkey and the Accessibility permission](46-clip-hotkey-and-permission.md) | 43 | done |
| 47 | [Clip from the clipboard](47-clip-from-clipboard.md) | none | done |
| 48 | [Clip Confirmation and Last Clip](48-clip-confirmation.md) | 47 | done |
| 49 | [Clip Hotkey captures the selection](49-clip-hotkey-capture.md) | 45, 46, 47, 48 | done |
| 50 | ["Clip to MacJot" Service](50-clip-service.md) | 47, 48 | done |
| 51 | [Frontmatter Section: auto-expand setting and Find](51-frontmatter-section-setting-and-find.md) | 44 | done |
| 52 | [Find expands Note metadata when only hidden text matches](52-find-expands-note-metadata.md) | none | ready-for-agent |
| 53 | [Global search also searches Note metadata](53-global-search-note-metadata.md) | none | ready-for-agent |

Statuses: `ready-for-agent` (can be picked up once its blockers are done) → `done` → `done` (checked by hand).

Planned order for the rest: 53 and 52 (soon). Images follow after a grilling that uses ticket 45's findings.
