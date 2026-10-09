#!/bin/sh
# Renders the Settings panes and the Note List offscreen, light and dark, at 2×,
# into the directory given (default: ./renders). Builds a throwaway package in
# $TMPDIR from MacJot's app sources plus main.swift here. Needs the sandbox off
# in Claude Code, like every swift build. Marks: swiftc mark.swift -o mark; see its header.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../.." && pwd)"
OUT="$(mkdir -p "${1:-renders}" && cd "${1:-renders}" && pwd)"
PKG="${TMPDIR:-/tmp}/macjot-render"
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
  case "$(basename "$f")" in main.swift|Settings.swift) ;; *) ln -s "$f" "$PKG/Sources/Render/" ;; esac
done
# The renderer needs the Settings window without showing it.
sed -e 's/private func makeWindow/func makeWindow/' -e 's/private func select(/func select(/' \
    -e 's/private var window: NSWindow?/var window: NSWindow?/' "$REPO/Sources/Jot/Settings.swift" > "$PKG/Sources/Render/Settings.swift"
cp "$HERE/main.swift" "$PKG/Sources/Render/main.swift"
cd "$PKG" && swift build 2>&1 | grep -E "error|Compiling Render|Build" | grep -v "search path"
"$PKG/.build/debug/Render" "$OUT"
