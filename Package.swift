// swift-tools-version: 6.2

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
            name: "Async Stream Buffering",
            targets: ["Async Stream Buffering"]
        )
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-async-primitives"),
        .package(path: "../../swift-primitives/swift-buffer-primitives"),
        .package(path: "../../swift-primitives/swift-reference-primitives"),
        .package(path: "../swift-clocks"),
        .package(path: "../swift-dependencies", traits: ["Clocks"]),
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
            ]
        ),

        // MARK: - Async Stream

        .target(
            name: "Async Stream",
            dependencies: [
                "Async Stream Core",
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Clocks Dependency", package: "swift-dependencies"),
                .product(name: "Reference Primitives", package: "swift-reference-primitives"),
            ]
        ),

        // MARK: - Async Stream Buffering

        .target(
            name: "Async Stream Buffering",
            dependencies: [
                "Async Stream Core",
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Clocks", package: "swift-clocks"),
            ]
        ),
        .target(
            name: "Async",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                "Async Sequence",
                "Async Stream",
                "Async Stream Buffering",
            ]
        ),
        .testTarget(
            name: "Async Sequence Tests",
            dependencies: [
                "Async",
            ]
        ),
        .testTarget(
            name: "Async Stream Tests",
            dependencies: [
                "Async",
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
