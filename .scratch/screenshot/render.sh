#!/bin/sh
# Renders the README screenshot offscreen: the Capture Panel with a sample Note
# open and the Note List beside it, light and dark, into the directory given
# (default: docs/ in the repo). Builds a throwaway package in $TMPDIR from
# MacJot's app sources plus main.swift here, like ../hig-audit/render. Needs the
# sandbox off in Claude Code, like every swift build.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$(mkdir -p "${1:-$REPO/docs}" && cd "${1:-$REPO/docs}" && pwd)"
PKG="${TMPDIR:-/tmp}/macjot-screenshot"
rm -rf "$PKG/Sources"; mkdir -p "$PKG/Sources/Render"
cat > "$PKG/Package.swift" <<SWIFT
// swift-tools-version:6.2
import PackageDescription
let package = Package(
    name: "Render",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$REPO"), .package(path: "$REPO/Vendor/KeyboardShortcuts")],
    targets: [.executableTarget(name: "Render", dependencies: [
        .product(name: "JotCore", package: "mac-notes"),
        .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
    ])]
)
SWIFT
for f in "$REPO"/Sources/Jot/*.swift; do
  case "$(basename "$f")" in main.swift|CapturePanelController.swift) ;; *) ln -s "$f" "$PKG/Sources/Render/" ;; esac
done
# The renderer needs the panel itself.
sed -e 's/    private let panel: CapturePanel/    let panel: CapturePanel/' \
    "$REPO/Sources/Jot/CapturePanelController.swift" > "$PKG/Sources/Render/CapturePanelController.swift"
cp "$HERE/main.swift" "$PKG/Sources/Render/main.swift"
cd "$PKG" && swift build 2>&1 | grep -E "error|Build" | grep -v "search path"
"$PKG/.build/debug/Render" "$OUT"
