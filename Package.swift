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
            name: "Async Stream",
            targets: ["Async Stream"]
        )
    ],
    dependencies: [
        .package(path: "../../swift-primitives/swift-async-primitives"),
        .package(path: "../../swift-primitives/swift-buffer-primitives"),
        .package(path: "../../swift-primitives/swift-reference-primitives"),
        .package(path: "../swift-dependencies/integration/swift-clocks-dependency"),
    ],
    targets: [
        .target(
            name: "Async Stream",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Clocks Dependency", package: "swift-clocks-dependency"),
                .product(name: "Reference Primitives", package: "swift-reference-primitives"),
            ]
        ),
        .target(
            name: "Async",
            dependencies: [
                .product(name: "Async Primitives", package: "swift-async-primitives"),
                "Async Stream"
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
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
