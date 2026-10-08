# 02: Capture Hotkey and floating panel

**What to build:** The user presses the Capture Hotkey (`⌃⌥N`, fixed default for now) from any app, including full-screen apps, and the Capture Panel appears as a floating panel above other windows on the current Space, with a new Draft ready for typing. The hotkey toggles: pressing it with the panel key hides it; pressing it with the panel visible but not key brings it to front keeping its content. `Esc` closes the panel. The panel hides when it loses focus while showing only an untouched Draft. `⌘N` starts a new Draft from anywhere in the panel. Size and position are remembered across launches; if the remembered screen is no longer connected the panel centres on the current screen. Registered via the Carbon hot-key API, so no Accessibility permission is requested.

**Blocked by:** 01

**Status:** done

- [ ] `⌃⌥N` from any app (incl. full-screen) shows the panel with a new Draft, cursor ready
- [ ] No Accessibility permission prompt
- [ ] Panel key + `⌃⌥N` → hides; panel visible but not key + `⌃⌥N` → front, content kept; panel hidden + `⌃⌥N` → new Draft
- [ ] Panel floats above normal windows and appears on the active Space
- [ ] `Esc` closes the panel; the Note is already saved
- [ ] Clicking elsewhere with an untouched Draft hides the panel; with content it stays
- [ ] `⌘N` starts a new Draft, leaving (and saving) the current Note
- [ ] Size and position persist across relaunch; with the remembered screen disconnected, panel centres on the current screen
