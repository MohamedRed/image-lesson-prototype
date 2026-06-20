// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "HealthFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HealthFeature",
            targets: ["HealthFeature"]),
    ],
    dependencies: [
        .package(path: "../HealthService"),
        .package(url: "https://github.com/stripe/stripe-ios", from: "23.0.0")
    ],
    targets: [
        .target(
            name: "HealthFeature",
            dependencies: [
                "HealthService",
                .product(name: "StripePaymentSheet", package: "stripe-ios")
            ]),
        .testTarget(
            name: "HealthFeatureTests",
            dependencies: ["HealthFeature"]),
    ]
)