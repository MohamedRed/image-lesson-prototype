// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FriendsFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FriendsFeature",
            targets: ["FriendsFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../FriendsService"),
        .package(path: "../LiveKitCore"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FriendsFeature",
            dependencies: [
                "FriendsService",
                "LiveKitCore",
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "FriendsFeatureTests",
            dependencies: ["FriendsFeature"]
        ),
    ]
)