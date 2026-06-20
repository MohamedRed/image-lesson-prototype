// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoodDeliveryFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FoodDeliveryFeature",
            targets: ["FoodDeliveryFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../FoodDeliveryService"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0"),
    ],
    targets: [
        .target(
            name: "FoodDeliveryFeature",
            dependencies: [
                "FoodDeliveryService",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
            ]
        ),
        .testTarget(
            name: "FoodDeliveryFeatureTests",
            dependencies: ["FoodDeliveryFeature"]
        ),
    ]
)