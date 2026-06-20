// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TripsFeature",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "TripsFeature",
            targets: ["TripsFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../TripsService"),
    ],
    targets: [
        .target(
            name: "TripsFeature",
            dependencies: [
                "TripsService"
            ]
        ),
        .testTarget(
            name: "TripsFeatureTests",
            dependencies: ["TripsFeature"]
        ),
    ]
)