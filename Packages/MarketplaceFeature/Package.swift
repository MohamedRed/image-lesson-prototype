// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarketplaceFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MarketplaceFeature",
            targets: ["MarketplaceFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../MarketplaceService"),
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", .upToNextMajor(from: "11.4.0"))
    ],
    targets: [
        .target(
            name: "MarketplaceFeature",
            dependencies: [
                "MarketplaceService",
                .product(name: "MapboxMaps", package: "mapbox-maps-ios")
            ]
        ),
        .testTarget(
            name: "MarketplaceFeatureTests",
            dependencies: ["MarketplaceFeature"]
        ),
    ]
)