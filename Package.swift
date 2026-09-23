// swift-tools-version: 6.0

import PackageDescription

// The application intentionally has no third-party dependencies. All UI,
// process management, persistence, and JSON-RPC code use Apple frameworks.
let package = Package(
    name: "QuotaBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QuotaBar", targets: ["QuotaBar"])
    ],
    targets: [
        .target(
            name: "CodexQuotaCore",
            path: "Sources/CodexQuotaCore"
        ),
        .executableTarget(
            name: "QuotaBar",
            dependencies: ["CodexQuotaCore"],
            path: "Sources/QuotaBar"
        ),
        // The host has Command Line Tools without XCTest/Swift Testing, so
        // tests are a dependency-free executable runner instead of a framework
        // test target. It remains runnable with `swift run QuotaBarTests`.
        .executableTarget(
            name: "QuotaBarTests",
            dependencies: ["CodexQuotaCore"],
            path: "Tests/QuotaBarTests"
        )
    ]
)
