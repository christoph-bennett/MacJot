# 52: Find expands Note metadata when only hidden text matches

**What to build:** With Find (⌘F) open on a Note whose Frontmatter Section is collapsed, typing a term that is found only in the hidden frontmatter expands the section and shows the match, so Find never looks like an error (a yellow sliver on the collapsed header). If the term also matches in the visible text, the section stays collapsed. Decided 2026-11-15: expand only when the hidden text holds the only matches. This works while typing (incremental search), not only on Return or Next, and replaces the selection-only reveal from ticket 51 so the two don't fight. Once expanded, it stays expanded until the Note closes or the user collapses it; clearing Find doesn't collapse it. Notes without frontmatter are unaffected.

**Blocked by:** None (ticket 51 is done).

**Status:** done

- [x] The check "are all matches inside the hidden range?" is a pure function with unit tests: only hidden, only visible, both, none, no frontmatter, already expanded.
- [x] Typing a term found only in the metadata (e.g. `created`) expands the section and the match is visible and selected.
- [x] A term found in both the metadata and the body leaves the section collapsed.
- [x] No yellow sliver remains on the collapsed header while Find is open.
- [x] Next/Previous that moves from visible matches to a hidden-only state follows the same rule.
- [x] The offscreen gutter harness shows no overlapping line numbers while Find expands (at most 100 trials).
- [x] Manual check in light and dark.
