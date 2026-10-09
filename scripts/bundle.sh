#!/bin/sh
# Builds Jot.app into build/ from the SwiftPM executable, without Xcode.
# Ad-hoc signed: fine for local use; notarised distribution needs a Developer ID.
set -e
cd "$(dirname "$0")/.."
CONFIG="${1:-release}"
swift build -c "$CONFIG" --product Jot
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP=build/Jot.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN_DIR/Jot" "$APP/Contents/MacOS/Jot"
# The hotkey recorder's texts; without them it crashes when it shows one.
cp -R "$BIN_DIR/KeyboardShortcuts_KeyboardShortcuts.bundle" "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
