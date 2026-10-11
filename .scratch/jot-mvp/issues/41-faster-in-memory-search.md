# 41: Faster in-memory search

**What to build:** Search (GLOSSARY: across all Notes, filtering the Note List) gets fast enough for 10,000 Notes (decided 2026-10-11, after ticket 40's benchmark: about 0.23 ms per Note today, over 50 ms from roughly 200 Notes). Each Note's search text (its Title and lines, Markdown removed as today) is folded once when it's loaded: case and accents removed. On each keystroke the query is folded once and each Note is checked with a plain byte search over its folded text. The preview line is still the first body line containing the first term found in the body, looked up as today, but only in a Note that matched. Results stay exactly as ticket 37 defines them; in a probe, folded matching agreed with today's on ß/ss, ü as one character or u plus an accent, the ﬁ ligature, İ, and Æ and ½ (matched by neither). The folded copy costs memory: about the size of the Notes again (about 57 MB at 20,000). Loading isn't part of this ticket (BACKLOG, Later: Faster loading).

Measured in the probe at 5,000 Notes (M3, release): today 1,174 ms for a search with no match; folded byte search 8.5 ms, plus 123 ms once at load for folding.

**Blocked by:** none

**Status:** done

- [x] Every existing Search test passes unchanged; new ones pin ß/ss, an accent typed separately, and the ﬁ ligature
- [x] The preview line is the same as before for word, several-word and phrase searches
- [x] A speed test in the test suite: searching 1,000 generated Notes takes under 50 ms in the debug build
- [x] `scripts/benchmark-search.sh` shows every search under 50 ms at 10,000 Notes; numbers recorded below

## Results

`scripts/benchmark-search.sh`, 2026-10-11, same Mac as ticket 40 (Mac15,3, M3, 16 GB, macOS 27.0.1); medians of 15.

| Notes | One word | Several words | Phrase | No match | Common word | Load |
|---|---|---|---|---|---|---|
| 1,000 | 1.5 ms | 1.8 ms | 2.4 ms | 1.7 ms | 0.6 ms | 416 ms |
| 5,000 | 7.6 ms | 8.9 ms | 12.0 ms | 8.8 ms | 3.0 ms | 2.03 s |
| 10,000 | 15.4 ms | 18.0 ms | 23.8 ms | 16.9 ms | 5.7 ms | 4.12 s |

Before (ticket 40), at 10,000: 2.16 s, 2.30 s, 2.31 s, 2.36 s, 522 ms. Search is about 100× faster; loading is about 8% slower (3.81 s → 4.12 s), the folding done once per Note.

Beyond the ticket's plan: the preview snippet is cut only when a row shows it. Building it for every match left a common word (9,740 matches) at 73 ms; a first typed letter matches almost every Note. The line and the place in it come from the folded match, so drawing a row needs no comparison.

One deliberate difference from before: part of a letter that folds to two (`ß` → `ss`, `ﬀ` → `ff`) now matches, so `stras` finds "Straße" (before, it dropped out at `stras` and came back at `strass`), and `s` finds "Fuß". Found in code review; pinned by `partOfAFoldedLetterMatches`.
