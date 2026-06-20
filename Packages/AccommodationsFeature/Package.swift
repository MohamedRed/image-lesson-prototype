// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AccommodationsFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AccommodationsFeature",
            targets: ["AccommodationsFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../AccommodationsService"),
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", from: "11.0.0"),
    ],
    targets: [
        .target(
            name: "AccommodationsFeature",
            dependencies: [
                "AccommodationsService",
                .product(name: "MapboxMaps", package: "mapbox-maps-ios"),
            ]
        ),
        .testTarget(
            name: "AccommodationsFeatureTests",
            dependencies: ["AccommodationsFeature"]
        ),
    ]
)