// swift-tools-version: 6.0

import PackageDescription

// The application intentionally has no third-party dependencies. All UI,
// process management, persistence, and JSON-RPC code use Apple frameworks.
let package = Package(
    name: "CodexQuotaMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexQuotaMonitor", targets: ["CodexQuotaMonitor"])
    ],
    targets: [
        .target(
            name: "CodexQuotaCore",
            path: "Sources/CodexQuotaCore"
        ),
        .executableTarget(
            name: "CodexQuotaMonitor",
            dependencies: ["CodexQuotaCore"],
            path: "Sources/CodexQuotaMonitor"
        ),
        // The host has Command Line Tools without XCTest/Swift Testing, so
        // tests are a dependency-free executable runner instead of a framework
        // test target. It remains runnable with `swift run CodexQuotaMonitorTests`.
        .executableTarget(
            name: "CodexQuotaMonitorTests",
            dependencies: ["CodexQuotaCore"],
            path: "Tests/CodexQuotaMonitorTests"
        )
    ]
)
