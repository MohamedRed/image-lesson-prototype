// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NewsFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NewsFeature",
            targets: ["NewsFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../NewsService")
    ],
    targets: [
        .target(
            name: "NewsFeature",
            dependencies: ["NewsService"]
        ),
        .testTarget(
            name: "NewsFeatureTests",
            dependencies: ["NewsFeature"]
        ),
    ]
)