# 20: Settings spacing

**What to build:** Settings gets one consistent spacing, from the HIG audit (`.scratch/hig-audit/`, findings 1 to 4), so a setting's parts sit together and settings are clearly apart:

- **Explanation under its control:** 4 pt below the control, on every pane; a second explanation line (Notes Folder) 4 pt below the first. The `blankLine` paddings go. (Finding 1)
- **Between settings (rows):** 16 pt, clearly more than inside a setting. (Finding 2)
- **Dividers:** 16 pt above and below. (Finding 3)
- ~~Explanations use the full column width~~ (finding 4): withdrawn, they already do; see the audit.

Keep the column layout (`Pane`, `Explanation`) and the window margins (30 pt sides, 20 pt top and bottom). Check with before/after offscreen renders of all three panes (`.scratch/hig-audit/render/render.sh`), then in the app.

**Blocked by:** 19

**Implementation note:** a `Grid` replaces the `.columns` form, whose row spacing can't be set; `Row` keeps the label read with its controls for VoiceOver. Dividers now span both columns (before: the control column only). Before/after renders: `.scratch/hig-audit/ticket-20/`.

**Status:** done

- [x] Every explanation is 4 pt below its control, on all three panes
- [x] Settings are 16 pt apart; dividers have 16 pt above and below
- [x] Before/after renders of all three panes, light and dark
