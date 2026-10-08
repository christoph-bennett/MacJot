#!/bin/sh
# Builds Jot.app into build/ from the SwiftPM executable, without Xcode.
# Ad-hoc signed: fine for local use; notarised distribution needs a Developer ID.
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
swift build -c "$CONFIG" --product Jot
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Jot"

APP=build/Jot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Jot"
codesign --force --sign - "$APP"
echo "Built $APP"
