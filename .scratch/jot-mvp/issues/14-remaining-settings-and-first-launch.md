# 14: Remaining settings and first launch

**What to build:** Settings is completed with: **Launch at login** toggle (default on, takes effect without restart), **font size** for the editor, **relative dates** toggle for the Note List (default on; off shows absolute dates in the system short format, e.g. `08.10.26, 07:15`), a single **Reset Panel Size & Position** button, and **line numbers** in the editor (on by default, toggle in Settings). Line numbers count the file's lines, so a wrapped line keeps one number and the blank lines between paragraphs are numbered too; they sit in a narrow gutter left of the text in small, dimmed SF Mono and follow light/dark. On first launch, with no onboarding flow, Jot creates the default Notes Folder, shows a brief hint near the status item listing both hotkeys, and opens a Draft.

**Blocked by:** 04, 05, 06, 07

**Status:** ready-for-agent

- [ ] Launch at login toggle reflects and changes the real login-item state immediately
- [ ] Font size change applies live to the editor and persists
- [ ] Relative dates off → Note List shows system short-format dates; on → "2h", "Mon"
- [ ] Reset Panel Size & Position restores default size, centred on the current screen
- [ ] Line numbers are shown by default, one per line of the file (wrapped lines keep one number; paragraph-gap blank lines are numbered)
- [ ] The Settings toggle hides and shows the line numbers live and persists across relaunch
- [ ] Line numbers stay aligned while typing, scrolling, resizing and changing the font size
- [ ] First launch (no prior preferences): folder created, hint shows both current hotkeys, Draft opens
- [ ] Hint does not appear on later launches
