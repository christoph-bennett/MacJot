#!/bin/sh
# Replaces ~/Applications/MacJot.app with build/MacJot.app (from scripts/bundle.sh)
# and starts it. Waits for the running MacJot to quit first, then retries
# starting it: for a moment after the old process has exited, `open` fails with
# error -600 (procNotFound), and nothing that can be queried (pgrep, lsappinfo,
# launchctl) shows when that moment is over (ticket 27).
set -e
cd "$(dirname "$0")/.."
[ -d build/MacJot.app ] || { echo "No build/MacJot.app: run scripts/bundle.sh first." >&2; exit 1; }
if pkill -x MacJot; then  # MacJot quits normally on SIGTERM, saving the open Note
  tries=0
  while pgrep -x MacJot >/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      echo "MacJot hasn't quit after 10 seconds (an alert open?). Quit it, then run this again." >&2
      exit 1
    fi
    sleep 0.1
  done
fi
rm -rf ~/Applications/MacJot.app
cp -R build/MacJot.app ~/Applications/
# MacJot opens Markdown files (ticket 30): only the installed copy should be
# offered in Finder's Open With, and with this build's document types.
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
"$LSREGISTER" -u "$PWD/build/MacJot.app" 2>/dev/null || true
"$LSREGISTER" -f ~/Applications/MacJot.app
tries=0
until open ~/Applications/MacJot.app 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -ge 10 ]; then
    echo "Installed, but MacJot didn't start after 5 seconds: open ~/Applications/MacJot.app yourself." >&2
    exit 1
  fi
  sleep 0.5
done
tries=0
until pgrep -x MacJot >/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -ge 50 ]; then
    echo "Installed, but MacJot isn't running 5 seconds after opening it." >&2
    exit 1
  fi
  sleep 0.1
done
echo "Installed and started ~/Applications/MacJot.app"
