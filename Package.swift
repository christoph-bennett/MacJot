// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Jot",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Jot", targets: ["Jot"]),
        .library(name: "JotCore", targets: ["JotCore"]),
    ],
    targets: [
        .target(name: "JotCore"),
        .executableTarget(name: "Jot", dependencies: ["JotCore"]),
        .testTarget(name: "JotCoreTests", dependencies: ["JotCore"]),
    ]
)
