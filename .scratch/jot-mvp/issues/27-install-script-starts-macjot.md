# 27: `install.sh` starts MacJot reliably

**What to build:** After `scripts/install.sh`, MacJot often doesn't start: `open ~/Applications/MacJot.app` fails with `_LSOpenURLsWithCompletionHandler() failed with error -600`, although the script already waits for the old process to quit (found 2026-10-09; starting it by hand afterwards works). Find the cause (candidates: Launch Services still holding the old bundle at the same path after `rm -rf` + `cp -R`, the login-item registration, timing) and fix it in the script, so one run always leaves the new build running. No app changes expected.

**Blocked by:** none

**Status:** done

- [x] Five runs of `scripts/bundle.sh && scripts/install.sh` in a row each end with the new build running, without error -600
- [x] With MacJot not running, `install.sh` still installs and starts it

**Cause (2026-10-10):** for up to about 0.25 s after the old process has exited, `open` fails with -600; copying the new bundle sometimes covered that window, so it failed about every other run. Nothing queryable shows when the window ends (pgrep, `lsappinfo`, the login item's launchd job are all gone at once), so the script retries `open` every 0.5 s for up to 5 s, then waits for the process. Five runs in a row and one with MacJot not running all ended with the new build running.
