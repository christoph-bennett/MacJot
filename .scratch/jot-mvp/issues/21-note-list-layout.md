# 21: Note List layout

**What to build:** The Note List gets more room, from the HIG audit (`.scratch/hig-audit/`, findings 6 to 9):

- **Width:** the list opens at 240 pt instead of its minimum (180 pt; maximum stays 320 pt), and the width the user drags to is remembered across launches (an autosave name on the split view). (Finding 6)
- **Rows:** 52 pt high instead of 44: 10 pt above the Title, 3 pt between the Title and the date/preview line, 10 pt below. No separators (decided 2026-10-09). (Finding 7)
- **Title font:** the Headline text style (13 pt bold) instead of 13 pt semibold; the date/preview line stays Subheadline (11 pt). (Finding 8)
- **Alignment:** the search field gets the row highlight's edges, 10 pt from both sides of the sidebar, and sits 10 pt below the title bar. (Finding 9)

The Capture Panel's default size (693 × 553 pt) stays; the editor keeps about 450 pt next to a 240 pt list. Check with before/after offscreen renders, then in the app (including Reset Size & Position and a collapsed and reopened list).

**Blocked by:** 19

**Status:** ready-for-agent

- [ ] The list opens at 240 pt; a dragged width survives quitting and relaunching
- [ ] Rows are 52 pt with the spacing above; Titles are 13 pt bold
- [ ] Search field and row highlights share their left and right edges
- [ ] Before/after renders, light and dark
