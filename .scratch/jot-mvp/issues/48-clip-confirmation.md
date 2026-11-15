# 48: Clip Confirmation

**What to build:** After a Clip is created, a pill-shaped overlay, the **Clip Confirmation**, says so (decided 2026-11-15, spec 0002). It shows "Added to MacJot" and the new Note's Title, cut to fit. It appears at the bottom centre of the screen the mouse is on, above all other windows including full-screen apps, never takes focus, lets clicks pass through, and fades in and out. How long it stays is set in Settings > General: 1 to 5 seconds in 0.5 s steps, 2 seconds by default.

**Blocked by:** 47 (Clip creation).

**Status:** ready-for-agent

- [ ] After a successful Clip the pill shows "Added to MacJot" and the Title; a long Title is cut and the pill stays one line.
- [ ] It appears on the screen the mouse is on, bottom centre, also over a full-screen app, and doesn't steal focus from the source app or catch clicks.
- [ ] It fades in and out; two Clips in quick succession show the second pill without stacking a leftover first one.
- [ ] Settings > General has the duration control (1 to 5 s, 0.5 s steps, default 2 s); a change applies to the next Clip and survives a restart.
- [ ] Looks right in light and dark, checked by hand; a failed Clip shows its alert and no pill.
