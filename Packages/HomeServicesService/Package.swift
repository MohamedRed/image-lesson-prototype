// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HomeServicesService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HomeServicesService",
            targets: ["HomeServicesService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "HomeServicesService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
            ]),
        .testTarget(
            name: "HomeServicesServiceTests",
            dependencies: ["HomeServicesService"]),
    ]
)