# 54: Capture Panel steps back when another app takes focus

**What to build:** With the Capture Panel open and holding a Note with content, switching to another app (⌘-Tab, a click on its window) no longer leaves the panel floating dimmed above that app. It drops to normal window level and sits behind the other app's windows, still open and unchanged. Bringing it back works as before: the Capture Hotkey or Search Hotkey, the menu bar item, or a click on any part of it still showing. Decided 2026-11-17 (grilled), from the BACKLOG Inbox item reported 2026-11-15.

Why the Key status, not app activation: the panel is non-activating, so summoning it by hotkey usually doesn't make MacJot the active app. Switching away then fires no "resign active", the panel only loses Key status. So the trigger is the panel resigning Key with no MacJot window Key afterwards (focus went to another app; an alert or Settings doesn't count). Returning to Key, and showing the panel, put it back at floating level; the existing return from System Settings (ticket 46) stays.

An untouched Draft still closes when focus leaves (ticket 2); only a panel with content steps back. The Clip Hotkey doesn't touch the panel (the Clip Confirmation never takes Key), so it neither raises nor lowers it.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [x] Panel with content, ⌘-Tab to another app: the panel sits behind that app's windows, not dimmed above them; its content is unchanged.
- [x] Capture Hotkey, Search Hotkey and the menu bar item each bring it back to the front, content kept (ticket 2), and writing continues.
- [x] Clicking a part of the stepped-back panel that still shows brings it to the front and makes it Key.
- [x] An untouched Draft still hides when focus leaves.
- [x] Opening Settings or an alert from the panel leaves it in front.
- [x] A Clip made while the panel is stepped back leaves its position as it is.
- [x] Manual check in light and dark; committed only after the user says "commit".
