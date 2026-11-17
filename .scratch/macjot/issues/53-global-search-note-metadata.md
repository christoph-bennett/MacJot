# 53: Global search also searches Note metadata

**What to build:** The search over all Notes (Note List search field) also matches a Note's frontmatter, so searching `9runzr` or `Safari` finds the Notes (e.g. Clips) whose metadata has it, as Find in the current Note already does. Wanted soon (2026-11-15). Today the search covers the Title and body lines only; the frontmatter is skipped on purpose. A match in the metadata becomes the row's preview, shown as the matching line (e.g. `source: Safari`), so the row shows why the Note matched. Body matches still take precedence for the preview, as the Title does today. Every word of the query must still be in the Note (Title, body or metadata). Opening such a Note from the results should leave the Frontmatter Section collapsed unless ticket 52's rule applies.

**Open points to settle at the start:** a search for a common source like "Safari" will match every Safari Clip; check this feels right in the real list (the user wants it anyway). Whether the preview shows the raw `key: value` line or only the value. Whether keys (`created`, `source`) are searchable or only values.

**Blocked by:** None (can start immediately). Related: 52.

**Status:** done

- [x] A word found only in a Note's frontmatter makes the Note a search result; a Note without it is not.
- [x] The row's preview shows the matching metadata line when nothing in the Title or body matches; a body match wins when both match.
- [x] Multi-word queries match across Title, body and metadata together.
- [x] Searching stays fast: the existing thousand-Notes performance test still passes (ticket 41).
- [x] Unit tests cover metadata-only, body-only, both, and Notes without frontmatter, in `NoteSummary` tests.
- [x] Manual check in light and dark.

Decided 2026-11-17: only values are searched, not keys (every Clip has `created`, `source`, `page`); the preview shows the whole `key: value` line.
