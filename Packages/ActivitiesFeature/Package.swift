// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ActivitiesFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "ActivitiesFeature",
            targets: ["ActivitiesFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../ActivitiesService"),
    ],
    targets: [
        .target(
            name: "ActivitiesFeature",
            dependencies: [
                "ActivitiesService",
            ]
        ),
        .testTarget(
            name: "ActivitiesFeatureTests",
            dependencies: ["ActivitiesFeature"]
        ),
    ]
)