// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Jot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jot", targets: ["Jot"]),
        .library(name: "JotCore", targets: ["JotCore"]),
    ],
    dependencies: [
        // Records and registers the global hotkeys (ADR 0005). Vendored with a patch: see its README.
        .package(path: "Vendor/KeyboardShortcuts"),
    ],
    targets: [
        .target(name: "JotCore"),
        .executableTarget(name: "Jot", dependencies: ["JotCore", "KeyboardShortcuts"]),
        .testTarget(name: "JotCoreTests", dependencies: ["JotCore"]),
    ]
)
