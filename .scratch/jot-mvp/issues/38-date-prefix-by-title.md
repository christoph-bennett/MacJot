# 38: Date Prefix found by the Title

**What to build:** The groundwork for a configurable Date Prefix Format (ADR 0009, decided 2026-10-11), with no new UI yet.

- **Renaming keeps any prefix:** when a Note's Title changes and it's renamed (ADR 0003), the Date Prefix it keeps is everything in its filename before the Title's own name (the slug, or slug-`N`), whatever format wrote it. `20261011_plan.md` with the Title "Plan" becomes `20261011_big-plan.md` when the Title becomes "Big plan". A filename that is just the Title's name has no prefix, including a Title that itself starts with a date (`2026-10-08 meeting` → `2026-10-08-meeting.md`). Only when the filename doesn't end with the Title's name does MacJot fall back to recognising a prefix in the current Date Prefix Format or the default one.
- **No date read from prefixes:** the creation date MacJot derived from a Note's prefix (or the file system) is shown nowhere and is removed.
- **The Date Prefix Format:** an ordered list of elements, stored as a setting, that writes a day as a prefix. Elements and their options (first is the default): **Year** `2026` / `26`; **Month** `10` / `3` / short name / full name; **Day** `09` / `9`; **Separator** `-` / `_` / `.` / space. Month names come from the system language and keep macOS's case, with accents dropped and a trailing dot removed (`Okt.` → `Okt`, `févr.` → `fevr`); in non-Latin scripts the name options aren't available. Any combination is valid, also an empty one, which writes no prefix. The default is Year, `-`, Month, `-`, Day, `-`: today's `2026-10-11-`, so nothing changes for the user yet.

**Blocked by:** none

**Status:** done

- [x] Renaming keeps a prefix in any format (e.g. `20261011_`, `11.10.26 `, `2026-`), and none for a filename that's just the Title's name
- [x] A Note whose filename doesn't end with its Title's name keeps a prefix in the current or default format when renamed
- [x] New Notes still get `2026-10-11-` style prefixes; existing behaviour and tests otherwise unchanged
- [x] The format writes every element option correctly, month names in English and e.g. German and French with the filename rules applied; non-Latin locales offer numbers only
