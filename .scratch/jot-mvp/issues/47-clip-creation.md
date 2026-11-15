# 47: Clip creation

**What to build:** With text selected in any app, pressing the Clip Hotkey creates a new Note from it, without opening the Capture Panel or taking focus (decided 2026-11-15, spec 0002, ADR 0010, ADR 0011).

- The selection is read by a sequence: snapshot every type on the general pasteboard, press ⌘C in the frontmost app, wait up to about 0.5 s for the pasteboard to change, read the plain text, restore the snapshot (marked transient where the pasteboard allows). No change in time means "no selection" and the clipboard is left untouched.
- The Note is written straight to the Notes Folder as a Note with a finished Title (not a Draft). The body is the selection verbatim; the Title is its first non-blank line after the frontmatter; filename, Date Prefix and collision suffix follow ADR 0003 unchanged. Repeating the same selection makes a second Note.
- The Note starts with frontmatter holding `created` (ISO 8601, local time with offset, seconds), `source` (the frontmost app's name) and `page` (its front window's title, whole). Values are double-quoted only when YAML needs it; unknown values are left out. Ordinary Notes still get no frontmatter.
- Failures show an alert that says what happened: nothing selected (or a field that blocks copying), MacJot itself in front ("Select text in another app"), or the Accessibility permission missing. A whitespace-only selection counts as empty and makes no Note. A very long selection is saved in full without a dialog.

There is no confirmation yet (ticket 48): the demo is that the Note appears in the Note List and in the Notes Folder.

**Blocked by:** 46 (Clip Hotkey and the Accessibility permission).

**Status:** ready-for-agent

- [ ] Seam 1 tests over a temporary Notes Folder with an injected clock: frontmatter keys and quoting (a page title with a colon, a quote, a leading symbol), omitted unknown values, the Title after the frontmatter, the filename with and without a Date Prefix, the collision suffix, and no file for a whitespace-only selection.
- [ ] Seam 3 tests with fakes for the pasteboard, key sender, clock and frontmost app: the clipboard is restored in every outcome, no change within the wait gives "no selection" and leaves the clipboard untouched, MacJot in front fails with its own reason, and the restore is marked transient.
- [ ] Clipping a selection from Safari, Mail and a text editor creates a Note whose frontmatter names the right app and window; the clipboard holds what it held before, including a non-text item (an image copied beforehand).
- [ ] Focus stays in the source app and the Capture Panel doesn't open; an open Capture Panel shows the new Note in its list without a reload.
- [ ] Each failure shows its alert; the missing-permission alert points to Settings > Shortcuts.
- [ ] The new Note's frontmatter shows in the Frontmatter Section if ticket 44 is done, and as plain YAML otherwise.
