// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-async",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
        .library(
            name: "Async",
            targets: ["Async"]
        ),
        .library(
            name: "Async Stream",
            targets: ["Async Stream"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-async-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", from: "0.0.1"),
        .package(url: "https://github.com/swift-primitives/swift-test-primitives.git", from: "0.0.1"),
    ],
    targets: [
        .target(
            name: "Async Stream",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
            ]
        ),
        .target(
            name: "Async",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                "Async Stream",
            ]
        ),
        .testTarget(
            name: "Async Stream Tests",
            dependencies: [
                "Async",
                .product(name: "Test Primitives", package: "swift-test-primitives"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
