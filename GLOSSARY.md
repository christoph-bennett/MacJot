# Mac Notes

A menu-bar app for capturing quick notes with a global hotkey and keeping them as plain Markdown files on the user's Mac.

## Language

**Note**:
One Markdown file in the Notes Folder; the unit the user captures, edits and searches.
_Avoid_: Document, entry, memo, jot

**Title**:
The first non-blank line of a Note, whatever its formatting; it names the Note in the Note List and determines its filename.
_Avoid_: Name, heading, subject

**Date Prefix**:
An optional date at the start of a Note's filename, recording the day the Note was created, written in the Date Prefix Format; enabled in Settings.
_Avoid_: Timestamp, date stamp

**Date Prefix Format**:
The pattern the Date Prefix is written in, built in Settings from date elements and separators; `2026-10-09-` by default.
_Avoid_: Template, mask, naming pattern

**Notes Folder**:
The single user-chosen folder whose top-level `.md` files are the user's Notes.
_Avoid_: Vault, library, notebook

**Capture Hotkey**:
The user-configurable global keystroke that summons the Capture Panel ready for writing.
_Avoid_: Shortcut, keybinding (when meaning this specific one)

**Search Hotkey**:
The user-configurable global keystroke that summons the Capture Panel with the Note List open and search focused.
_Avoid_: Find shortcut

**Capture Panel**:
The floating window, summoned by either hotkey, in which a Note is written and the Note List is shown.
_Avoid_: Popover, editor window, popup

**Note List**:
The collapsible sidebar of the Capture Panel listing Notes by Title, filterable by search.
_Avoid_: Library, browser, index

**Draft**:
A Note opened in the Capture Panel that has no file in the Notes Folder yet, because it is blank or its Title isn't finished.
_Avoid_: Empty note, unsaved note

**Recovery Copy**:
A hidden backup of a Draft's text, kept outside the Notes Folder until the Draft gets its file, so a crash never loses it.
_Avoid_: Temp file, autosave file, backup

**Outside File**:
A Markdown file opened in the Capture Panel from elsewhere; shown read-only until it's moved into the Notes Folder, when it becomes a Note.
_Avoid_: External note, foreign file, guest file

**Search**:
Looking for text across all Notes, by filtering the Note List.
_Avoid_: Find (that's within one Note), filter

**Find**:
Looking for (and optionally replacing) text within the open Note.
_Avoid_: Search (that's across Notes)

**Formatting Toolbar**:
The row of controls that applies Markdown formatting to the selection, for users who don't type the syntax.
_Avoid_: Format bar, ribbon

**Search Index**:
A disposable, derived copy of the Notes' contents used only to make search fast; never a source of truth.
_Avoid_: Database, DB, store
