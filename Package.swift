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
        .executableTarget(
            name: "CodexQuotaMonitor",
            path: "Sources/CodexQuotaMonitor"
        )
    ]
)
