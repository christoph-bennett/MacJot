#!/bin/sh
# Random-edit run against the real Capture Panel, offscreen: after every step it
# checks that the line numbers the gutter would draw are sequential and never
# overlap (tickets 44, 51, 52). Usage: run.sh [trials] (default 100, keep it small).
# Builds a throwaway package in $TMPDIR like ../screenshot/render.sh. Needs the sandbox off.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
PKG="${TMPDIR:-/tmp}/macjot-gutter-harness"
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
sed -e 's/    private let panel: CapturePanel/    let panel: CapturePanel/' \
    -e 's/    private let textView: NSTextView/    let textView: NSTextView/' \
    "$REPO/Sources/Jot/CapturePanelController.swift" > "$PKG/Sources/Render/CapturePanelController.swift"
cp "$HERE/main.swift" "$PKG/Sources/Render/main.swift"
cd "$PKG" && swift build 2>&1 | grep -E "error|Build" | grep -v "search path"
"$PKG/.build/debug/Render" "${1:-100}"
