// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AITutorService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AITutorService",
            targets: ["AITutorService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "AITutorService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ]),
        .testTarget(
            name: "AITutorServiceTests",
            dependencies: ["AITutorService"]),
    ]
)