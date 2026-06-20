// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DebateFeature",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "DebateFeature",
            targets: ["DebateFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../DebateService"),
        .package(path: "../LiveKitCore"),
    ],
    targets: [
        .target(
            name: "DebateFeature",
            dependencies: [
                "DebateService",
                "LiveKitCore",
            ]
        ),
        .testTarget(
            name: "DebateFeatureTests",
            dependencies: ["DebateFeature"]
        ),
    ]
)