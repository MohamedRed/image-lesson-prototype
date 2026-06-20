// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "EventsService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EventsService",
            targets: ["EventsService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "EventsService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "EventsServiceTests",
            dependencies: ["EventsService"]
        ),
    ]
)