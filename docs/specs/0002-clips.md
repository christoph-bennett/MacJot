# Spec 0002: Clips

Status: ready-for-agent

Vocabulary follows [GLOSSARY.md](../../GLOSSARY.md). Respects [ADR 0001](../adr/0001-markdown-files-are-source-of-truth.md), [ADR 0003](../adr/0003-filenames-follow-title.md), [ADR 0005](../adr/0005-keyboardshortcuts-for-hotkeys.md), [ADR 0008](../adr/0008-one-flat-notes-folder.md), and introduces [ADR 0010](../adr/0010-clips-carry-frontmatter.md) and [ADR 0011](../adr/0011-clips-are-read-through-the-pasteboard.md). Decided in a grilling on 2026-11-15.

## Problem Statement

I read, browse and work in other apps, and now and then a passage deserves keeping. Today that means copying it, summoning MacJot, pasting, and giving it a Title, and I lose where it came from. I want to select text anywhere, press one key combination, and have it appear as a new Note, with a record of the app and page it came from, without leaving what I was doing.

## Solution

A third global hotkey, the **Clip Hotkey** (⌃⌥C by default, configurable in Settings > Shortcuts). With text selected in any app, pressing it creates a new Note from the selection (a **Clip**) in the Notes Folder, and a small pill, the **Clip Confirmation**, says it was added. The Capture Panel doesn't open and focus never leaves the app I was in. The Clip's file starts with YAML frontmatter recording `created`, `source` (the app) and `page` (the window or page title). The editor shows frontmatter in a visually separate, collapsible **Frontmatter Section**, in every Note that has one, so the YAML doesn't clutter reading. If nothing could be read, an alert says why.

Images, rich text, and a Clip's URL are not part of this spec. A small developer tool that shows what is on the system pasteboard is built first so the image decisions that follow rest on facts.

## User Stories

1. As a user, I want to press a hotkey with text selected in any app, so that the text becomes a new Note without my opening MacJot.
2. As a user, I want the Clip Hotkey to be ⌃⌥C by default, so that it works at once and sits beside the Capture Hotkey and the Search Hotkey.
3. As a user, I want to record a different Clip Hotkey in Settings > Shortcuts, so that it fits my other shortcuts.
4. As a user, I want the recorder to warn me when the combination is taken by the other MacJot hotkeys or by macOS, so that I don't lose a hotkey without noticing.
5. As a user, I want Restore Defaults in Shortcuts to include the Clip Hotkey, so that all three can be reset together.
6. As a user, I want to be able to clear the Clip Hotkey, so that I can turn the feature off.
7. As a user, I want the Capture Panel to stay closed when I clip, so that I keep reading where I was.
8. As a user, I want keyboard focus to stay in the app I clipped from, so that I can go on typing or selecting at once.
9. As a user, I want the Clip to work in browsers, mail, PDF viewers and editors alike, so that I don't have to remember where it works.
10. As a user, I want my clipboard to hold what it held before, so that clipping never destroys something I had copied.
11. As a user, I want the clipboard restored also when clipping fails, so that a failure costs me nothing.
12. As a user, I want a pill-shaped overlay saying "Added to MacJot" with the new Note's Title, so that I know it worked and which Note it became.
13. As a user, I want the Clip Confirmation at the bottom centre of the screen my mouse is on, so that I see it without looking elsewhere.
14. As a user, I want the Clip Confirmation to appear above full-screen apps, so that it works while I read full-screen.
15. As a user, I want the Clip Confirmation never to take focus and to let clicks pass through, so that it never gets in my way.
16. As a user, I want the Clip Confirmation to fade in and out, so that it feels like a system HUD, not a dialog.
17. As a user, I want to set how long the Clip Confirmation stays in Settings > General, from 1 to 5 seconds in half-second steps, so that it suits my reading speed.
18. As a user, I want the default duration to be 2 seconds, so that it is sensible without my configuring anything.
19. As a user, I want a long Title cut to fit in the Clip Confirmation, so that the pill stays small.
20. As a user, I want an alert when nothing is selected, so that I understand why no Note appeared.
21. As a user, I want an alert when I press the Clip Hotkey with MacJot in front, saying to select text in another app, so that I'm not left guessing.
22. As a user, I want a secure input field or an app that blocks copying to count as "no selection", so that the Clip fails clearly instead of saving something else.
23. As a user, I want no Note created from a selection that is only whitespace, so that blank files don't pile up.
24. As a user, I want a very long selection saved in full without a confirmation dialog, so that clipping stays one keystroke.
25. As a user, I want the first non-blank line of the selection to be the Note's Title, so that Clips are named like every other Note.
26. As a user, I want the Clip's filename to follow the usual rules (slug, Date Prefix as set in Settings, collision suffix), so that Clips sit with my other Notes.
27. As a user, I want two Clips of the same text to become two Notes, so that nothing is silently dropped or merged.
28. As a user, I want the selection in the Note body exactly as selected, with no quote block or wrapper, so that I can edit it like anything I wrote.
29. As a user, I want only plain text in the first version, so that a Clip never carries half-converted formatting.
30. As a user, I want the Clip's frontmatter to record `created` as local time with offset, so that I can tell when I clipped it.
31. As a user, I want the frontmatter to record `source`, the app the selection came from, so that I remember where it was.
32. As a user, I want the frontmatter to record `page`, the window or page title, whole and not cut, so that I can find the page again.
33. As a user, I want values quoted in the YAML only when needed, so that a title with a colon or a quote still gives valid frontmatter.
34. As a user, I want an unknown `source` or `page` left out, never written empty, so that the frontmatter holds no noise.
35. As a user, I want the same key names as the app Jot (`created`, `source`, `page`), so that my Clips stay readable in both apps.
36. As a user, I want ordinary Notes still to get no frontmatter, so that my own Notes stay clean.
37. As a user, I want existing frontmatter in any file preserved verbatim, so that Notes from other tools don't change.
38. As a user, I want the Title still found after the frontmatter, so that a Clip isn't titled `---`.
39. As a user, I want the frontmatter shown in a visually separate section at the top of the editor, so that I can tell it from the text.
40. As a user, I want the Frontmatter Section collapsible by a chevron in its header row, so that the YAML can be out of the way.
41. As a user, I want the collapsed section to show one summary line such as "Safari · Personal — Finis — Write your book", so that I still see the Source at a glance.
42. As a user, I want the collapsed line to read "Properties" when the frontmatter has neither `source` nor `page`, so that the section is never empty.
43. As a user, I want the expanded section to be editable raw YAML on a faintly tinted band with a hairline below it, so that it reads as separate and I can still change it.
44. As a user, I want the cursor unable to land inside the collapsed section, so that I never type into hidden text.
45. As a user, I want Find to expand the section when it matches inside it, so that a hit is never hidden.
46. As a user, I want a Settings option "Expand frontmatter when a Note opens", off by default, so that I choose how Notes open.
47. As a user, I want my manual expanding or collapsing to last only while the Note is open, so that no hidden per-Note state builds up.
48. As a user, I want a View menu item "Show/Hide Frontmatter" with ⌥⌘P, so that I can toggle it from the keyboard.
49. As a user, I want that item greyed out in a Note without frontmatter, so that it is clear it does nothing there.
50. As a user, I want the frontmatter lines to get no line numbers and not be counted, so that the Title is line 1 and the numbers don't jump when I collapse or expand.
51. As a user, I want the section to appear in every Note that has closed frontmatter, not only Clips, so that all my Notes behave alike.
52. As a user, I want the Accessibility permission explained in Settings > Shortcuts, with its status ("granted" / "not granted") and an Open Privacy Settings button, so that I know what to do when a Clip fails.
53. As a user, I want the system's permission prompt shown once on the first Clip without the permission, followed by the failure alert, so that I'm guided without being nagged.
54. As a user, I want the Accessibility permission to survive reinstalling MacJot, so that I don't have to grant it after every update.
55. As a developer, I want a small separate tool that lists every item on the system pasteboard with its types, byte sizes and previews, so that I can see what each app really provides before deciding how images are handled.
56. As a developer, I want that tool to refresh when the clipboard changes, so that I can watch what an app puts on it.
57. As a developer, I want that tool to press ⌘C in the frontmost app on a button, so that I can see what the Clip sequence would read from any app.
58. As a developer, I want that tool kept out of the MacJot app bundle and the install, so that it never ships.

## Implementation Decisions

- **The Clip Hotkey** is a third named hotkey beside Capture and Search, recorded, stored and registered with the same library (ADR 0005). Default ⌃⌥C. Its conflict warnings, clearing and Restore Defaults behave like the other two.
- **Reading the selection** is a sequence behind one small interface: snapshot every type on the general pasteboard, press ⌘C in the frontmost app, wait up to about half a second for the pasteboard's change count to move, read the plain text, restore the snapshot. The wait is a constant, not a setting. No change within the wait means "no selection" and the clipboard is left untouched. The restore marks the pasteboard as transient where the pasteboard allows it, so that clipboard managers can skip it; they will still see the ⌘C (ADR 0011).
- **Failures** are reported with an alert that says what happened and what to do: nothing selected (or a field that blocks copying), MacJot is in front ("Select text in another app"), Accessibility permission missing. A selection of only whitespace counts as empty and makes no Note. There is no size limit and no confirmation dialog.
- **The Accessibility permission** is needed to send ⌘C. On the first Clip without it, MacJot asks the system to show its prompt once, then shows the failure alert. Settings > Shortcuts shows the permission's status and a button that opens the matching Privacy Settings pane.
- **Signing** comes first: the bundle script signs with the Apple Development identity when the keychain has one and falls back to ad-hoc signing otherwise, because the permission is tied to the code signature and an ad-hoc signature changes with every build. A check that the grant survives a reinstall is part of that ticket. Notarisation stays under "Install Xcode" in Later.
- **Source** is the frontmost application's name and the title of its front window, both read when the hotkey is pressed and before anything else changes. Either may be unknown and is then left out.
- **Creating the Note** is one operation of the Notes Folder: given the selection text, the Source and the current time, it writes a Note directly, as a Note with a finished Title, not as a Draft and not through the Capture Panel. The Title is the first non-blank line after the frontmatter; filename, Date Prefix and collisions follow ADR 0003 unchanged. The body is the selection verbatim.
- **Frontmatter written** has exactly `created` (ISO 8601, local time with offset, seconds, no milliseconds), `source` and `page`. Values are double-quoted only when YAML requires it. Unknown values are omitted. Ordinary Notes get none (ADR 0010).
- **The Frontmatter Section** applies to every Note with closed frontmatter at the top. The file text never changes; only the display does. The Note stays one text buffer, so saving, undo, Find and the Recovery Copy are unaffected. Collapsing hides the frontmatter lines the way paragraph gaps are hidden (no height) and puts a header row with a chevron above them; the header row shows the summary line. Expanded, the raw YAML stays editable in the existing grey monospace, on a faintly tinted band with a hairline below. The cursor skips the collapsed lines, as it skips paragraph gaps. A Find match inside the section expands it.
- **Frontmatter Section state**: the Settings option (Settings > Editor, off by default) decides how a Note opens; a manual toggle, by chevron or by the View menu item "Show/Hide Frontmatter" (⌥⌘P, greyed out without frontmatter), lasts only while the Note stays open and is stored nowhere.
- **Line numbers** skip the frontmatter lines and don't count them, like paragraph gaps; the Title line is line 1.
- **The Clip Confirmation** is a borderless, non-activating, click-through pill window above all other windows including full-screen apps, at the bottom centre of the screen the mouse is on. It shows "Added to MacJot" and the Title cut to fit, fades in and out, and stays for a duration set in Settings > General (1 to 5 seconds in 0.5 s steps, default 2 s).
- **The pasteboard inspector** is a separate developer executable in the repository, like the search benchmark: not in the app bundle, not installed. It lists each pasteboard item with its types, byte sizes and previews (text, RTF, HTML, images), refreshes on change, and has a button that presses ⌘C in the frontmost app and shows the result. It avoids Swift macros so it builds with the Command Line Tools.
- **Ticket order**: (1) signing prefactor; (2) Frontmatter Section; (3) pasteboard inspector; (4) Clip Hotkey recorder and permission status, blocked by 1; (5) Clip creation, blocked by 4; (6) Clip Confirmation and its setting, blocked by 5.

## Testing Decisions

- **Good tests** exercise external behaviour only: given inputs at a seam, assert files on disk, returned text, or returned outcomes. No assertions on private state, call order or internal helpers.
- **Seam 1, Notes Folder (existing).** Creating a Clip over a real temporary directory with an injected clock. Asserts on the resulting file: the frontmatter keys and their quoting, omitted unknown values, the Title after the frontmatter, the filename with and without a Date Prefix, a collision suffix for a repeated selection, and no file for a whitespace-only selection. Prior art: the Notes Folder tests for filenames and the Date Prefix.
- **Seam 2, pure text functions (existing, table-driven).** Finding the frontmatter range, the collapsed summary line (with `source` and `page`, with only one, with neither), and line numbering that skips the frontmatter lines so the Title is line 1. Prior art: the line-number tests, the Title and frontmatter cases in the editing tests.
- **Seam 3, Clip capture sequence (new).** The sequence behind its interface (pasteboard, key sender, clock, frontmost app), with fakes. Asserts that the clipboard is restored in every outcome, that no change within the wait gives "no selection" and leaves the clipboard untouched, that a whitespace-only selection counts as empty, that MacJot being in front fails with the matching reason, and that the restore is marked transient. This seam is new because a wrong restore destroys the user's clipboard and the real pasteboard can't be tested reliably.
- **Not automated**, checked by hand against a short list per ticket: the hotkey recorder and its warnings; the permission prompt, status line and Privacy Settings button; the grant surviving a reinstall; the Clip Confirmation (place, fade, duration, no focus, above a full-screen app); the Frontmatter Section (chevron, ⌥⌘P, Settings option, cursor skipping, Find expanding it); the inspector against a few real apps (a browser, Mail, a PDF viewer).

## Out of Scope

- Images and attachments in Clips. They get their own grilling after the inspector has shown what apps put on the pasteboard; ADR 0008 and the flat Notes Folder are in tension with attachment files.
- Rich text to Markdown conversion; a Clip's URL; a Services menu entry (all Later, see the backlog).
- Appending a selection to an existing Note (Not planned).
- Per-Note or remembered collapsed state; editing frontmatter through form fields instead of raw YAML.
- Writing frontmatter into ordinary Notes, or fields other than `created`, `source` and `page`.
- Notarisation and Xcode (Later).

## Further Notes

- The reference was the app Jot, which Christoph tested beside MacJot. It writes `archived`, `created`, `done`, `id`, `images`, `pin`, `section`, `source`, `page`, `tags` and `updated`, cuts `page` at about 50 characters, names files by date and id, and keeps an `attachments/inbox` folder. MacJot takes only the key names `created`, `source` and `page`.
- The first Clip ticket that needs the Accessibility permission must wait for the signing prefactor, or the grant resets at every install.
- The Frontmatter Section is useful on its own and ships before any Clip code; it is the only part that changes how existing Notes look.
