#!/bin/sh
# Replaces ~/Applications/Jot.app with build/Jot.app (from scripts/bundle.sh)
# and starts it. Waits for the running Jot to quit first: opening while it's
# still quitting fails with error -600.
set -e
cd "$(dirname "$0")/.."
[ -d build/Jot.app ] || { echo "No build/Jot.app: run scripts/bundle.sh first." >&2; exit 1; }
if pkill -x Jot; then  # Jot quits normally on SIGTERM, saving the open Note
  tries=0
  while pgrep -x Jot >/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 100 ]; then
      echo "Jot hasn't quit after 10 seconds (an alert open?). Quit it, then run this again." >&2
      exit 1
    fi
    sleep 0.1
  done
fi
rm -rf ~/Applications/Jot.app
cp -R build/Jot.app ~/Applications/
open ~/Applications/Jot.app
echo "Installed and started ~/Applications/Jot.app"
