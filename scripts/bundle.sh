#!/bin/sh
# Builds MacJot.app into build/ from the SwiftPM executable, without Xcode.
# Ad-hoc signed: fine for local use; notarised distribution needs a Developer ID.
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
swift build -c "$CONFIG" --product MacJot
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP=build/MacJot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_DIR/MacJot" "$APP/Contents/MacOS/MacJot"
# The hotkey recorder's texts; without them it crashes when it shows one.
cp -R "$BIN_DIR/KeyboardShortcuts_KeyboardShortcuts.bundle" "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
