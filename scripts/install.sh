#!/bin/sh
# Replaces ~/Applications/MacJot.app with build/MacJot.app (from scripts/bundle.sh)
# and starts it. Waits for the running MacJot to quit first: opening while it's
# still quitting fails with error -600.
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
open ~/Applications/MacJot.app
echo "Installed and started ~/Applications/MacJot.app"
