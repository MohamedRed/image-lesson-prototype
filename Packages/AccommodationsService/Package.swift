// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AccommodationsService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AccommodationsService",
            targets: ["AccommodationsService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
        .package(url: "https://github.com/stripe/stripe-ios.git", from: "23.0.0"),
    ],
    targets: [
        .target(
            name: "AccommodationsService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "StripePaymentSheet", package: "stripe-ios"),
            ]
        ),
        .testTarget(
            name: "AccommodationsServiceTests",
            dependencies: ["AccommodationsService"]
        ),
    ]
)