# 14: Remaining settings and first launch

**What to build:** Settings is completed with: **Launch at login** toggle (default on, takes effect without restart), **font size** for the editor, **relative dates** toggle for the Note List (default on; off shows absolute dates in the system short format, e.g. `08.10.26, 07:15`), a single **Reset Panel Size & Position** button, an **Ask before moving notes to the Trash** toggle (default on; the confirmation itself exists since ticket 05), and **line numbers** in the editor (on by default, toggle in Settings). Line numbers count the file's lines, so a wrapped line keeps one number and the blank lines between paragraphs are numbered too; they sit in a narrow gutter left of the text, styled as described under **Gutter look** below. On first launch, with no onboarding flow, Jot creates the default Notes Folder, shows a brief hint near the status item listing both hotkeys, and opens a Draft.

**Gutter look** (modelled on STTextView's gutter, which the user liked: github.com/krzyzanowskim/STTextView, files `Sources/STTextViewAppKit/Gutter/STGutterView.swift`, `STGutterLineNumberCell.swift`, `STGutterSeparatorView.swift`, and the snapshot images under `Tests/STTextViewAppKitTests/__Snapshots__/GutterSnapshotTests/`. GPL v3: take the design, write our own code.)

- **Digits:** the system font (SF Pro), regular weight, condensed, with tabular (monospaced) figures so numbers of the same width line up; lining figures, slashed zero. Not SF Mono: the condensed SF digits are narrower and quieter. Roughly the body text's size, so a number sits level with its line.
- **Colour:** `secondaryLabelColor`, so they're dimmed and follow light/dark by themselves.
- **Alignment:** right-aligned towards the text, 6 pt from the separator, 4 pt inset on the left. Each number sits on the baseline of the first line of its file line; continuation lines of a wrapped line get no number.
- **Width:** at least about 35 pt; it grows when the numbers gain a digit (99 → 100), never per keystroke otherwise.
- **Separator:** a 1 pt vertical hairline at the gutter's right edge, pixel-aligned, in `separatorColor` at about 10 % opacity: barely there, but it marks the edge. Then about 5 pt of space before the text.
- **Background:** the same as the text's, no separate band (STTextView uses a visual-effect view with the content-background material inside the window, following the window's active state).
- **Not now, but possible later** (it has them as options): highlighting the current line's number with `selectedTextBackgroundColor` at about 25 % opacity and a stronger number colour; this pairs with the backlog's "highlight the current line". When word wrap can be turned off (backlog), the gutter stays put while the text scrolls sideways.

**Blocked by:** 04, 05, 06, 07

**Status:** ready-for-agent

- [ ] Launch at login toggle reflects and changes the real login-item state immediately
- [ ] Font size change applies live to the editor and persists
- [ ] Relative dates off → Note List shows system short-format dates; on → "2h", "Mon"
- [ ] Reset Panel Size & Position restores default size, centred on the current screen
- [ ] With "Ask before moving notes to the Trash" off, deleting from the Note List, context menu or `⋯` trashes immediately; on (default) shows the confirmation
- [ ] Line numbers are shown by default, one per line of the file (wrapped lines keep one number; paragraph-gap blank lines are numbered)
- [ ] The Settings toggle hides and shows the line numbers live and persists across relaunch
- [ ] Line numbers stay aligned while typing, scrolling, resizing and changing the font size
- [ ] First launch (no prior preferences): folder created, hint shows both current hotkeys, Draft opens
- [ ] Hint does not appear on later launches
