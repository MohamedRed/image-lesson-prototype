// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DebateService",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "DebateService",
            targets: ["DebateService"]
        ),
    ],
    dependencies: [
        .package(path: "../LiveKitCore"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "DebateService",
            dependencies: [
                "LiveKitCore",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "DebateServiceTests",
            dependencies: ["DebateService"]
        ),
    ]
)