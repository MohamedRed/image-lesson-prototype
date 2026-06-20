// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoodDeliveryService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FoodDeliveryService",
            targets: ["FoodDeliveryService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        .package(url: "https://github.com/radarlabs/radar-sdk-ios", from: "3.9.0"),
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0"),
    ],
    targets: [
        .target(
            name: "FoodDeliveryService",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "RadarSDK", package: "radar-sdk-ios"),
                .product(name: "Stripe", package: "stripe-ios"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
            ]
        ),
        .testTarget(
            name: "FoodDeliveryServiceTests",
            dependencies: ["FoodDeliveryService"]
        ),
    ]
)