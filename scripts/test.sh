#!/bin/sh
# Runs the test suite with only the Command Line Tools installed (no Xcode).
# The default swift-build backend uses explicit modules and drops the
# Swift Testing macro plugin, so use the native build system and point it
# at the Testing.framework that ships with the CLT.
set -e
cd "$(dirname "$0")/.."
DEV="$(xcode-select -p)"
case "$DEV" in
  */CommandLineTools) ;;
  *) exec swift test "$@" ;;  # full Xcode selected: no workaround needed
esac
F="$DEV/Library/Developer/Frameworks"
exec swift test --build-system native \
  -Xswiftc -F"$F" -Xlinker -F"$F" -Xlinker -rpath -Xlinker "$F" "$@"
