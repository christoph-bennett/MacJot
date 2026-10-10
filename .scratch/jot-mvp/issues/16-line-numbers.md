# 16: Line numbers

**What to build:** Line numbers in the editor, on by default, with a checkbox in Settings > Editor (the pane ticket 14 starts) that hides and shows them live. They count the file's lines, so a wrapped line keeps one number and the blank lines between paragraphs are numbered too. They sit in a narrow gutter left of the text, styled as described under **Gutter look** below. Moved out of ticket 14 at the user's request. The editor runs on TextKit 1 (`EditorLayoutManager`), which gives the line fragment positions the gutter needs.

**Gutter look** (modelled on STTextView's gutter, which the user liked: github.com/krzyzanowskim/STTextView, files `Sources/STTextViewAppKit/Gutter/STGutterView.swift`, `STGutterLineNumberCell.swift`, `STGutterSeparatorView.swift`, and the snapshot images under `Tests/STTextViewAppKitTests/__Snapshots__/GutterSnapshotTests/`. GPL v3: take the design, write our own code.)

- **Digits:** SF Mono, regular, 2 pt smaller than the body text, as in Xcode, drawn on whole pixels. (Changed after the user tried it: the spec's condensed SF Pro with tabular figures looked a few pixels off between numbers, and the user preferred SF Mono from a comparison of six variants.)
- **Colour:** `secondaryLabelColor`, so they're dimmed and follow light/dark by themselves.
- **Alignment:** right-aligned towards the text, 6 pt from the separator, 4 pt inset on the left. Each number sits on the baseline of the first line of its file line; continuation lines of a wrapped line get no number.
- **Width:** at least about 35 pt; it grows when the numbers gain a digit (99 → 100), never per keystroke otherwise.
- **Separator:** a 1 pt vertical hairline at the gutter's right edge, pixel-aligned, in `separatorColor` at about 10 % opacity: barely there, but it marks the edge. Then about 5 pt of space before the text.
- **Background:** the same as the text's, no separate band (STTextView uses a visual-effect view with the content-background material inside the window, following the window's active state).
- **Not now, but possible later** (it has them as options): highlighting the current line's number with `selectedTextBackgroundColor` at about 25 % opacity and a stronger number colour; this pairs with the backlog's "highlight the current line". When word wrap can be turned off (backlog), the gutter stays put while the text scrolls sideways.

**Changed later (ticket 23, 2026-10-09):** paragraph gaps are no longer numbered.

**Blocked by:** 07, 14

**Status:** done

- [x] Line numbers are shown by default, one per line of the file (wrapped lines keep one number; paragraph-gap blank lines are numbered)
- [x] The Settings toggle hides and shows the line numbers live and persists across relaunch
- [x] Line numbers stay aligned while typing, scrolling, resizing and changing the font size
