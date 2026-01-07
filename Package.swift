// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-async",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "Async",
            targets: ["Async"]
        ),
        .library(
            name: "Async Primitives",
            targets: ["Async Primitives"]
        ),
        .library(
            name: "Async Stream",
            targets: ["Async Stream"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-kernel"),
        .package(path: "../swift-buffer"),
        .package(path: "../../swift-standards/swift-standards")
    ],
    targets: [
        .target(
            name: "Async Primitives",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "StandardsCollections", package: "swift-standards"),
            ],
            path: "Sources/Async Primitives"
        ),
        .target(
            name: "Async Stream",
            dependencies: [
                "Async Primitives",
                .product(name: "Kernel", package: "swift-kernel"),
                .product(name: "Buffer", package: "swift-buffer"),
            ],
            path: "Sources/Async Stream"
        ),
        .target(
            name: "Async",
            dependencies: [
                "Async Primitives",
                "Async Stream",
            ],
            path: "Sources/Async"
        ),
        .testTarget(
            name: "Async Primitives Tests",
            dependencies: [
                "Async Primitives",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Async Primitives Tests"
        ),
        .testTarget(
            name: "Async Stream Tests",
            dependencies: [
                "Async Stream",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Async Stream Tests"
        ),
    ]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility")
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
