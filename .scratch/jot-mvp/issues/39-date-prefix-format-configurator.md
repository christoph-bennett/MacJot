# 39: Date Prefix Format configurator

**What to build:** The Date Prefix Format can be configured in Settings > General, in the style of Hazel's renaming patterns (decided 2026-10-11). A **Format…** button next to the Date Prefix checkbox, greyed out and inactive while the checkbox is off, opens a popover with:

- a token field (`NSTokenField`) holding the format's elements as tokens; it accepts no typed text;
- a palette below it with **Year**, **Month**, **Day** and **Separator**: clicking one adds it at the insertion point, or it's dragged into place;
- each token in the field has a ▾ menu with its options (ticket 38): Year `2026` / `26`; Month `10` / `3` / short name / full name (names in the system language, numbers only in non-Latin scripts); Day `09` / `9`; Separator `-` / `_` / `.` / space (shown as "space");
- **Example:** the prefix for today followed by a sample Title, e.g. `2026-10-11-groceries.md`, updated live;
- **Restore Default** (Year `-` Month `-` Day `-`) and **Done**.

Tokens are reordered by dragging and removed with Delete; any token may appear more than once, and no combination is refused: an empty format writes no prefix. No hints about sorting. Changing the format applies to new Notes only; existing files keep their names.

**Blocked by:** 38

**Status:** ready-for-agent

- [ ] Format… sits next to the Date Prefix checkbox, greyed out while it's off; it opens the popover
- [ ] Tokens are added by click or drag, reordered by drag, removed with Delete; typing adds nothing
- [ ] Each token's ▾ menu offers its options, first one by default; month names follow the system language
- [ ] The Example updates with every change; Restore Default brings back `2026-10-11-`
- [ ] New Notes get the configured prefix; the format is remembered across launches; existing files keep their names
- [ ] Looks native in light and dark mode
