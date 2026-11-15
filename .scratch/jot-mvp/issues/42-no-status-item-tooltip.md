# 42: No tooltip on the status item

**What to build:** The menu bar status item no longer sets a tooltip. Hovering the icon shows nothing, and the "MacJot" ghost tooltip can no longer appear with all windows closed.

**Blocked by:** None (can start immediately).

**Status:** done

- [ ] The status button has no tooltip (`toolTip` is nil) after the status item is created.
- [ ] A test or check confirms this; if the AppKit setup isn't testable, the ticket notes that.
- [ ] `swift build` is clean and `scripts/test.sh` passes.
- [ ] Manual check: the ghost tooltip doesn't come back after a few days of normal use.
