# 17: Rename to MacJot

**What to build:** The app is called MacJot everywhere users and the system see it (ADR 0006): all user-facing texts (menus, alerts, Settings, the first-launch hint, the status item's tooltip and accessibility description), `CFBundleName`/`CFBundleDisplayName`, the app bundle `MacJot.app`, the executable and process name `MacJot`, bundle ID `com.onethingwell.macjot`, and `~/Library/Application Support/MacJot/` for the Recovery Copy. `scripts/bundle.sh` and `scripts/install.sh` build and install `MacJot.app`; `CLAUDE.md`, the handoff notes and BACKLOG.md use the new name where they mean the app (e.g. the Inbox item about registering on the services dashboard). Not renamed: the Swift modules and types (`Jot`, `JotCore`, `JotCoreTests`), the repo folder and `.scratch/jot-mvp/`. New installs default to the Notes Folder `~/Documents/MacJot`; an existing Notes Folder is never moved or renamed.

**Moving the user's data (once, by the agent, not in the app):** the new bundle ID starts with empty UserDefaults, which would look like a first launch (default Notes Folder, hint, hotkeys and cursor positions gone). So when installing the renamed app for the first time:
1. Quit Jot.
2. Unregister its login item (`SMAppService.mainApp.unregister()` from the old app, or remove it under System Settings > General > Login Items), so no entry points at a deleted app.
3. Copy the `com.onethingwell.jot` defaults into `com.onethingwell.macjot` (`defaults export` / `defaults import`); keep the old domain as a backup.
4. Delete `~/Applications/Jot.app` and `~/Library/Application Support/Jot/` (after checking `recovery.md` holds nothing unsaved).
5. Install and start MacJot; it registers its own login item on first run only if `didRegisterLoginItem` isn't set, so check the toggle in Settings matches what the user had.

**Blocked by:** 18

**Status:** ready-for-agent

- [ ] No user-visible text says "Jot" any more (menus, alerts, Settings, hint, tooltip, About)
- [ ] The installed app is `~/Applications/MacJot.app`, its process is `MacJot`, its bundle ID `com.onethingwell.macjot`
- [ ] After the move, MacJot opens the user's `~/Documents/Jot` with the same settings, hotkeys, cursor positions and panel frame, and shows no first-launch hint
- [ ] Exactly one login item, for MacJot; the old Jot.app and its Application Support folder are gone
- [ ] A fresh install (no preferences) creates `~/Documents/MacJot`
