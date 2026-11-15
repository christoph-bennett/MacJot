#!/bin/sh
# Builds MacJot.app into build/ from the SwiftPM executable, without Xcode.
# Signed with the Apple Development certificate from the keychain when there is a
# valid one (ticket 43, ADR 0011): macOS ties permissions such as Accessibility to
# the code signature, and an ad-hoc signature changes with every build, so each
# install would lose them. Without a usable certificate it falls back to ad-hoc
# signing, loudly. MACJOT_SIGN_IDENTITY=<name or hash> picks another identity.
# Notarised distribution needs a Developer ID (BACKLOG, Later: Install Xcode).
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
# Made by scripts/make-icon.sh from the artwork.
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
# The hotkey recorder's texts; without them it crashes when it shows one.
cp -R "$BIN_DIR/KeyboardShortcuts_KeyboardShortcuts.bundle" "$APP/Contents/Resources/"

IDENTITY="${MACJOT_SIGN_IDENTITY:-$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development: [^"]*\)".*/\1/p' | head -1)}"
CERTS="$(mktemp -d)"
trap 'rm -rf "$CERTS"' EXIT
if [ -n "$IDENTITY" ] && codesign --force --sign "$IDENTITY" "$APP" 2>"$CERTS/sign.err"; then
  # The signing certificate's expiry, read from the signed app: warn a month ahead.
  # Informational only: a failure here must not stop the build.
  APP_ABS="$PWD/$APP"
  (cd "$CERTS" && codesign -d --extract-certificates "$APP_ABS" 2>/dev/null) || true
  if [ -f "$CERTS/codesign0" ] && EXPIRES="$(openssl x509 -inform der -in "$CERTS/codesign0" -noout -enddate 2>/dev/null | sed 's/notAfter=//')" && [ -n "$EXPIRES" ]; then
    if ! openssl x509 -inform der -in "$CERTS/codesign0" -noout -checkend 2592000 >/dev/null 2>&1; then
      echo "WARNING: the signing certificate expires on $EXPIRES (within 30 days). After that the build is" >&2
      echo "         signed ad-hoc, and Accessibility and similar grants reset at every install." >&2
    fi
    echo "Signed with $IDENTITY (certificate valid until $EXPIRES)"
  else
    echo "Signed with $IDENTITY"
  fi
else
  codesign --force --sign - "$APP"
  if [ -n "$IDENTITY" ]; then REASON="could not sign with \"$IDENTITY\""; else REASON="no valid Apple Development certificate in the keychain"; fi
  echo "WARNING: signed ad-hoc ($REASON)." >&2
  [ -s "$CERTS/sign.err" ] && sed 's/^/         codesign: /' "$CERTS/sign.err" >&2
  echo "         Accessibility and similar grants will reset on every install." >&2
fi
echo "Built $APP"
