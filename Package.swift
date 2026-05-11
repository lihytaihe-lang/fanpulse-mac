// swift-tools-version: 6.0
// This package intentionally stays very small:
// one executable target, one placeholder test target, and no third-party dependencies.
//
// That makes the project easier to:
// - copy to another Mac,
// - rebuild in place if the binary is missing,
// - audit later when revisiting the private SMC behavior.

import PackageDescription

let package = Package(
    name: "fanpulse",
    platforms: [
        // The tool targets modern Apple Silicon-era macOS behavior.
        .macOS(.v12),
    ],
    targets: [
        // The executable target contains the entire tool: CLI flow plus SMC access layer.
        .executableTarget(
            name: "fanpulse"
        ),
        // Tests are currently minimal, but the target stays here so future protocol-level tests
        // have a standard home.
        .testTarget(
            name: "fanpulseTests",
            dependencies: ["fanpulse"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
