// swift-tools-version: 6.3.1

import PackageDescription

let package = Package(
    name: "swift-async",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Async",
            targets: ["Async"]
        ),
        .library(
            name: "Async Sequence",
            targets: ["Async Sequence"]
        ),
        .library(
            name: "Async Stream",
            targets: ["Async Stream"]
        ),
        .library(
            name: "Async Test Support",
            targets: ["Async Test Support"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-async-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-ring-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-queue-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-reference-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-standard-library-extensions.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-clocks.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-dependencies.git", branch: "main", traits: ["Clocks"]),
        .package(url: "https://github.com/swift-primitives/swift-memory-heap-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Async Sequence",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
            ]
        ),

        // MARK: - Async Stream Core (internal-only)

        .target(
            name: "Async Stream Core",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Queue Primitives", package: "swift-queue-primitives"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Reference Primitives", package: "swift-reference-primitives"),
            ]
        ),

        // MARK: - Async Stream

        .target(
            name: "Async Stream",
            dependencies: [
                "Async Stream Core",
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-ring-primitives"),
                .product(name: "Clocks Dependency", package: "swift-dependencies"),
                .product(name: "Standard Library Extensions", package: "swift-standard-library-extensions"),
            ]
        ),

        .target(
            name: "Async",
            dependencies: [
                "Async Sequence",
                "Async Stream",
            ]
        ),
        // MARK: - Test Support

        .target(
            name: "Async Test Support",
            dependencies: [
                "Async",
            ],
            path: "Tests/Support"
        ),

        // MARK: - Tests

        .testTarget(
            name: "Async Sequence Tests",
            dependencies: [
                "Async Test Support",
            ]
        ),
        .testTarget(
            name: "Async Stream Tests",
            dependencies: [
                "Async Test Support",
                .product(name: "Clocks Dependency", package: "swift-dependencies"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
