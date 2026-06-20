// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NewsService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NewsService",
            targets: ["NewsService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "NewsService",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk")
            ]
        ),
        .testTarget(
            name: "NewsServiceTests",
            dependencies: ["NewsService"]
        ),
    ]
)