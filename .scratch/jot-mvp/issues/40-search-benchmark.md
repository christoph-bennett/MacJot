# 40: Search benchmark

**What to build:** A script, `scripts/benchmark-search.sh`, that measures whether Search (GLOSSARY: across all Notes, filtering the Note List) stays fast as the Notes Folder grows (decided 2026-10-11). It decides whether the Search Index (BACKLOG, Later) gets built. It's run by hand and isn't part of `scripts/test.sh`. It generates Notes in a temporary folder, never the Notes Folder: 1,000, 5,000 and 10,000 of them, in English and German text, 200 B to 20 KB with most around 2 KB, some with headings, lists and a fenced code block. It times MacJot's own code (JotCore) for loading the Notes Folder into the Note List and for matching a search, using one word, several words and a phrase.

Thresholds: a search shows its results within **50 ms** of a keystroke; loading the Notes Folder takes under **1 s**. If both hold at 10,000 Notes, the Search Index stays in Later. If one fails, fix the slow part first; that may be loading, not search.

**Blocked by:** none

**Status:** done

- [x] `scripts/benchmark-search.sh` generates the three sizes in a temporary folder and removes them afterwards
- [x] It reports load time and search time (one word, several words, a phrase) for each size against the thresholds
- [x] It runs JotCore's real loading and matching code, not a copy
- [x] The numbers are recorded below, with the Mac they were measured on

## Results

Measured 2026-10-11 on a Mac15,3, Apple M3, 16 GB, macOS 27.0.1; release build, medians of 3 loads and of 15 searches (3 when a search is over 500 ms). Generated Notes average 2.9 KB. Takes about 1½ minutes.

| Notes | Load (≤ 1 s) | Reload after autosave | One word | Several words | Phrase | No match | Common word |
|---|---|---|---|---|---|---|---|
| 1,000 | 385 ms | 6 ms | 224 ms | 237 ms | 239 ms | 244 ms | 54 ms |
| 5,000 | **1.91 s** | 31 ms | 1.10 s | 1.19 s | 1.17 s | 1.20 s | 263 ms |
| 10,000 | **3.81 s** | 62 ms | 2.16 s | 2.30 s | 2.31 s | 2.36 s | 522 ms |

Every search is over 50 ms at all three sizes; load is over 1 s from 5,000 Notes.

- **Search** grows linearly, about 0.23 ms per Note, so it passes 50 ms at roughly 200 Notes. A search that finds a match early in each Note ("common word") is about 4× faster, so the cost is the comparison itself: case- and diacritic-insensitive `range(of:)` on every body line, on every keystroke. `Content.match` compares a matching Note's lines twice (once to check every term, again to find the preview line), and `NoteSummary.matching` splits the query into terms again for every Note.
- These are lower bounds for search: only the matching is timed. The Note List's own work per keystroke (building rows, reloading the table) comes on top.
- **Load** is about 0.38 ms per Note (reading and summarising each file; not broken down further), so it passes 1 s at roughly 2,600 Notes. Measured with the files in the disk cache; a first launch after a restart may be slower.
- **Reload** after an autosave stays small (unchanged files aren't read again).
