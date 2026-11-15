# 50: "Clip to MacJot" Service

**What to build:** A Service named "Clip to MacJot" appears in the Services menu of apps that offer selected text, and makes a Clip from it (decided 2026-11-15, spec 0002, ADR 0011 as revised). The app itself hands over the selection, so this path needs no Accessibility permission, no ⌘C and no clipboard change. It is the sturdier second path beside the Clip Hotkey, and it works in Safari, Chrome, Pages and Terminal (checked by hand).

The Note is made like every other Clip (ticket 47's creation, the Clip Confirmation from ticket 48), with `source` set to the frontmost app's name and no `page` (the window title needs the Accessibility permission; if it has been granted, the same cleaned `page` as in ticket 49 is added). Settings > Shortcuts gets a line saying the Service's own shortcut is set in System Settings > Keyboard > Shortcuts > Services, with a button that opens that pane.

**Blocked by:** 47 (Clip from the clipboard), 48 (Clip Confirmation and Last Clip).

**Status:** done

- [ ] The Service is registered by the installed app and appears under Services in Safari, Chrome, Pages and Terminal when text is selected, and not when nothing is selected.
- [ ] Choosing it makes a Note with the selection, the right `source`, no `page` without the permission, and the Clip Confirmation; the clipboard is untouched.
- [ ] A shortcut assigned in System Settings runs it from the keyboard.
- [ ] Settings > Shortcuts explains where the shortcut is set and the button opens the right pane.
- [ ] `scripts/bundle.sh` and the Info.plist declare the Service so that a reinstall keeps it registered, and the ticket records how to refresh the Services cache if it doesn't appear.

## Notes

- The Service is declared in `Resources/Info.plist` (`NSServices`: menu item "Clip to MacJot", message `clipToMacJot`, port `MacJot`, send types plain text); `scripts/bundle.sh` copies the plist and `scripts/install.sh` registers the installed app, so a reinstall keeps it.
- If it doesn't appear in an app's Services menu: `/System/Library/CoreServices/pbs -update`, then restart that app (or log out and in). `pbs -dump_pboard | grep -A8 "Clip to MacJot"` shows whether it is registered.
- The Service sets no `url` (the Service hands over text only). `source` is the frontmost app; `page` only with the permission granted.
- macOS 27 does not turn a new Service on by itself (checked 2026-11-15): it appears in an app's Services menu only after it is ticked in System Settings > Keyboard > Keyboard Shortcuts > Services > Text (the entry was there after `pbs -update`; restarting Safari alone didn't help). Settings > Shortcuts says so.
- When the Service runs, MacJot is already the frontmost app (the first build got no `source`), so `source` comes from the app that was in front before MacJot (`FrontAppTracker`, from workspace activation notifications).
