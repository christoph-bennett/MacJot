# 19: HIG audit of Settings and the Note List

**What to build:** An audit, not fixes: the user feels Settings and the Note List look cramped. Check their layout, spacing, sizing and typography against Apple's Human Interface Guidelines and Apple's own apps, and list what differs, for the user to decide on. Approved findings become their own tickets.

**Scope:**
- **Settings:** all three panes (General, Editor, Shortcuts) and the window around them: margins, space between rows and groups, label column, explanations, dividers, button and control sizes.
- **Note List:** everything in the pane: search field, rows (Title, date, selection, separators), empty and no-results states, the pane's width and its divider.

**References:** the HIG pages on Settings, Layout, Sidebars, Lists and Tables, and Typography; Safari, Mail and Finder Settings (toolbar switcher on top, labels in a right-aligned column) and Apple Notes' note list, measured where the HIG gives no numbers. Settled decisions stay (the segmented switcher in the toolbar, the column layout, `native-macos-controls`); the audit checks how they're spaced and sized, not whether to have them.

**Delivery:** `.scratch/hig-audit/README.md` with numbered findings. Each finding has what's there now, what the HIG or the reference app does (with the source), the proposed change, and an offscreen render of the current state with the spot marked (light mode; dark mode where it matters). The user answers per number: fix, skip, or change. Before/after renders come with the fix tickets.

**Blocked by:** 17 (so renders and texts show the new name)

**Status:** ready-for-agent

- [ ] Every Settings pane and the Note List pane is covered, each with a current render
- [ ] Each finding names its source (HIG page or measured Apple app)
- [ ] Findings are numbered and the user has answered each one
- [ ] Approved findings are written up as tickets
