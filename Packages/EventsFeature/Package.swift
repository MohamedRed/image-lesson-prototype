// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "EventsFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EventsFeature",
            targets: ["EventsFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../EventsService"),
        .package(path: "../FriendsService"),
    ],
    targets: [
        .target(
            name: "EventsFeature",
            dependencies: [
                "EventsService",
                "FriendsService",
            ]
        ),
        .testTarget(
            name: "EventsFeatureTests",
            dependencies: ["EventsFeature"]
        ),
    ]
)