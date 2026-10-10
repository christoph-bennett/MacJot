# 27: `install.sh` starts MacJot reliably

**What to build:** After `scripts/install.sh`, MacJot often doesn't start: `open ~/Applications/MacJot.app` fails with `_LSOpenURLsWithCompletionHandler() failed with error -600`, although the script already waits for the old process to quit (found 2026-10-09; starting it by hand afterwards works). Find the cause (candidates: Launch Services still holding the old bundle at the same path after `rm -rf` + `cp -R`, the login-item registration, timing) and fix it in the script, so one run always leaves the new build running. No app changes expected.

**Blocked by:** none

**Status:** ready-for-agent

- [ ] Five runs of `scripts/bundle.sh && scripts/install.sh` in a row each end with the new build running, without error -600
- [ ] With MacJot not running, `install.sh` still installs and starts it
