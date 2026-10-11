# 41: Faster in-memory search

**What to build:** Search (GLOSSARY: across all Notes, filtering the Note List) gets fast enough for 10,000 Notes (decided 2026-10-11, after ticket 40's benchmark: about 0.23 ms per Note today, over 50 ms from roughly 200 Notes). Each Note's search text (its Title and lines, Markdown removed as today) is folded once when it's loaded: case and accents removed. On each keystroke the query is folded once and each Note is checked with a plain byte search over its folded text. The preview line is still the first body line containing the first term found in the body, looked up as today, but only in a Note that matched. Results stay exactly as ticket 37 defines them; in a probe, folded matching agreed with today's on ß/ss, ü as one character or u plus an accent, the ﬁ ligature, İ, and Æ and ½ (matched by neither). The folded copy costs memory: about the size of the Notes again (about 57 MB at 20,000). Loading isn't part of this ticket (BACKLOG, Later: Faster loading).

Measured in the probe at 5,000 Notes (M3, release): today 1,174 ms for a search with no match; folded byte search 8.5 ms, plus 123 ms once at load for folding.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Every existing Search test passes unchanged; new ones pin ß/ss, an accent typed separately, and the ﬁ ligature
- [ ] The preview line is the same as before for word, several-word and phrase searches
- [ ] A speed test in the test suite: searching 1,000 generated Notes takes under 50 ms in the debug build
- [ ] `scripts/benchmark-search.sh` shows every search under 50 ms at 10,000 Notes; numbers recorded below

## Results

Not measured yet.
