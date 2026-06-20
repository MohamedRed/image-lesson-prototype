// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RideSharingService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RideSharingService",
            targets: ["RideSharingService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
        .package(url: "https://github.com/radarlabs/radar-sdk-ios", from: "3.9.0"),
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0"),
        .package(path: "../LiveKitCore")
    ],
    targets: [
        .target(
            name: "RideSharingService",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "RadarSDK", package: "radar-sdk-ios"),
                .product(name: "Stripe", package: "stripe-ios"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
                "LiveKitCore"
            ]
        ),
        .testTarget(
            name: "RideSharingServiceTests",
            dependencies: ["RideSharingService"]
        ),
    ]
)
 