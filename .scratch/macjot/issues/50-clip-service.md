# 50: "Clip to MacJot" Service

**What to build:** A Service named "Clip to MacJot" appears in the Services menu of apps that offer selected text, and makes a Clip from it (decided 2026-11-15, spec 0002, ADR 0011 as revised). The app itself hands over the selection, so this path needs no Accessibility permission, no ⌘C and no clipboard change. It is the sturdier second path beside the Clip Hotkey, and it works in Safari, Chrome, Pages and Terminal (checked by hand).

The Note is made like every other Clip (ticket 47's creation, the Clip Confirmation from ticket 48), with `source` set to the frontmost app's name and no `page` (the window title needs the Accessibility permission; if it has been granted, the same cleaned `page` as in ticket 49 is added). Settings > Shortcuts gets a line saying the Service's own shortcut is set in System Settings > Keyboard > Shortcuts > Services, with a button that opens that pane.

**Blocked by:** 47 (Clip from the clipboard), 48 (Clip Confirmation and Last Clip).

**Status:** ready-for-agent

- [ ] The Service is registered by the installed app and appears under Services in Safari, Chrome, Pages and Terminal when text is selected, and not when nothing is selected.
- [ ] Choosing it makes a Note with the selection, the right `source`, no `page` without the permission, and the Clip Confirmation; the clipboard is untouched.
- [ ] A shortcut assigned in System Settings runs it from the keyboard.
- [ ] Settings > Shortcuts explains where the shortcut is set and the button opens the right pane.
- [ ] `scripts/bundle.sh` and the Info.plist declare the Service so that a reinstall keeps it registered, and the ticket records how to refresh the Services cache if it doesn't appear.
