# 43: Sign the app with the Apple Development identity

**What to build:** Installing MacJot no longer resets permissions macOS ties to the app's code signature (decided 2026-11-15, spec 0002, ADR 0011). Today the bundle script signs ad-hoc, and an ad-hoc signature changes with every build, so an Accessibility grant would be lost at every install. The bundle script signs with the Apple Development identity when the keychain has one, and falls back to ad-hoc signing when it has none or the signing fails, so a build never breaks on another Mac. Which identity was used is printed. Notarisation stays under "Install Xcode" in Later.

The check that matters runs on a real permission: grant any signature-bound permission (Accessibility, via System Settings) to the installed app, install a rebuilt copy, and see that the grant is still there. That is the demo, and it is checked by hand.

**Blocked by:** None (can start immediately).

**Status:** done

- [x] With the Apple Development identity in the keychain, the bundle script signs with it, and `codesign -dv` on the built app shows that identity, not ad-hoc.
- [x] Without a usable identity the script still produces an ad-hoc-signed app and says so loudly: "Accessibility and similar grants will reset on every install". It also warns when the identity expires within 30 days, so the fallback never happens unnoticed after the certificate lapses.
- [x] The vendored KeyboardShortcuts resource bundle and everything else the script copies are signed in a way that keeps the app launching (the app starts and the hotkeys work after install).
- [x] Manual check: Accessibility granted to the installed MacJot is still granted after `scripts/install.sh` installs a rebuilt copy.
- [x] `SERVICES.md` and the registry manifest are updated if the install or process details changed.
