# 48: Clip Confirmation and Last Clip

**What to build:** After a Clip is created, a pill-shaped overlay, the **Clip Confirmation**, says so (decided 2026-11-15, spec 0002; extended after a sparring session). It shows "Added to MacJot" and the new Note's Title, cut to fit. It appears at the bottom centre of the screen the mouse is on, above all other windows including full-screen apps, never takes focus, lets clicks pass through, and fades in and out. How long it stays is set in Settings > General: 1 to 5 seconds in 0.5 s steps, 2 seconds by default. It is shown for every way of making a Clip, starting with Clip from Clipboard (ticket 47), so feedback exists before the hotkey capture does.

Because the pill is the only success signal and a missed pill looks like a failure, the status menu also gets "Last Clip": it shows the Title of the most recent Clip made since MacJot started and opens that Note when chosen; before any Clip it is greyed out.

**Blocked by:** 47 (Clip from the clipboard).

**Status:** ready-for-agent

- [ ] After a Clip from the clipboard the pill shows "Added to MacJot" and the Title; a long Title is cut and the pill stays one line.
- [ ] It appears on the screen the mouse is on, bottom centre, also over a full-screen app and on a second display, and doesn't steal focus or catch clicks.
- [ ] It fades in and out; two Clips in quick succession show the second pill without a leftover first one.
- [ ] Settings > General has the duration control (1 to 5 s, 0.5 s steps, default 2 s); a change applies to the next Clip and survives a restart.
- [ ] "Last Clip" is greyed out before any Clip, shows the latest Title after one, and opens that Note, also when the Note was renamed since.
- [ ] Looks right in light and dark, checked by hand; a failed Clip shows its alert and no pill.
