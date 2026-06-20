// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MarketplaceService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MarketplaceService",
            targets: ["MarketplaceService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        .package(url: "https://github.com/radarlabs/radar-sdk-ios", from: "3.9.0"),
    ],
    targets: [
        .target(
            name: "MarketplaceService",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "RadarSDK", package: "radar-sdk-ios"),
            ]
        ),
        .testTarget(
            name: "MarketplaceServiceTests",
            dependencies: ["MarketplaceService"]
        ),
    ]
)