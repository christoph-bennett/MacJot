# 37: Search by several words

**What to build:** Search (GLOSSARY: across all Notes, filtering the Note List) matches several words in any order (decided 2026-10-10; chosen over an SQLite word index, which would lose matching inside words). Words separated by spaces must all appear somewhere in the Note, Title or any line, in any order, each also as part of a word, as single words do today. Text in double quotes (straight or curly) is one exact phrase. Case and accents are still ignored. The Note List's preview line shows the line with the first word that matched; a match in the Title shows no extra line, as now. The open Draft's row follows the same rule.

**Blocked by:** none

**Status:** done

- [x] `milk friday` finds a Note with "Friday" in its Title and "oat milk" in a line, and not one with only one of them
- [x] `"buy milk"` finds only Notes with that exact phrase; `buy milk` also finds "milk to buy"
- [x] `rgen` still finds "Morgen"; case and accents are ignored
- [x] The preview line shows the first word's match; a Title match shows none
- [x] The Draft row is listed by the same rule
