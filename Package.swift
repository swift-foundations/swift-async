// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-runtime",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "Runtime",
            targets: ["Runtime"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-kernel"),
        .package(path: "../../swift-standards/swift-standards")
    ],
    targets: [
        .target(
            name: "Runtime",
            dependencies: [
                .product(name: "Kernel", package: "swift-kernel"),
            ]
        ),
        .testTarget(
            name: "Runtime Tests",
            dependencies: [
                "Runtime",
                .product(name: "StandardsTestSupport", package: "swift-standards")
            ],
            path: "Tests/Runtime Tests"
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
