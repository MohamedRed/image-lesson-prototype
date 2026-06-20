// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AITutorFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AITutorFeature",
            targets: ["AITutorFeature"]),
    ],
    dependencies: [
        .package(path: "../AITutorService"),
    ],
    targets: [
        .target(
            name: "AITutorFeature",
            dependencies: ["AITutorService"]),
        .testTarget(
            name: "AITutorFeatureTests",
            dependencies: ["AITutorFeature"]),
    ]
)