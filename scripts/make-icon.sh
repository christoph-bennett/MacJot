#!/bin/sh
# Builds Resources/AppIcon.icns from the artwork. Run it again when the artwork changes;
# bundle.sh only copies the result.
set -e
cd "$(dirname "$0")/.."
ARTWORK="${1:-Resources/AppIcon.png}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

swift scripts/make-icon.swift "$ARTWORK" "$WORK/icon-1024.png"
SET="$WORK/AppIcon.iconset"
mkdir "$SET"
for px in 16 32 128 256 512; do
    sips -z $px $px "$WORK/icon-1024.png" --out "$SET/icon_${px}x${px}.png" >/dev/null
    double=$((px * 2))
    sips -z $double $double "$WORK/icon-1024.png" --out "$SET/icon_${px}x${px}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Built Resources/AppIcon.icns"
