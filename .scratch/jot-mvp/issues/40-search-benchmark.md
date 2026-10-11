# 40: Search benchmark

**What to build:** A script, `scripts/benchmark-search.sh`, that measures whether Search (GLOSSARY: across all Notes, filtering the Note List) stays fast as the Notes Folder grows (decided 2026-10-11). It decides whether the Search Index (BACKLOG, Later) gets built. It's run by hand and isn't part of `scripts/test.sh`. It generates Notes in a temporary folder, never the Notes Folder: 1,000, 5,000 and 10,000 of them, in English and German text, 200 B to 20 KB with most around 2 KB, some with headings, lists and a fenced code block. It times MacJot's own code (JotCore) for loading the Notes Folder into the Note List and for matching a search, using one word, several words and a phrase.

Thresholds: a search shows its results within **50 ms** of a keystroke; loading the Notes Folder takes under **1 s**. If both hold at 10,000 Notes, the Search Index stays in Later. If one fails, fix the slow part first; that may be loading, not search.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] `scripts/benchmark-search.sh` generates the three sizes in a temporary folder and removes them afterwards
- [ ] It reports load time and search time (one word, several words, a phrase) for each size against the thresholds
- [ ] It runs JotCore's real loading and matching code, not a copy
- [ ] The numbers are recorded below, with the Mac they were measured on

## Results

Not measured yet.
