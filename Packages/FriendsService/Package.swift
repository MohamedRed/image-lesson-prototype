// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FriendsService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "FriendsService",
            targets: ["FriendsService"]
        ),
    ],
    dependencies: [
        .package(path: "../LiveKitCore"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.20.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "FriendsService",
            dependencies: [
                "LiveKitCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "Collections", package: "swift-collections")
            ]
        ),
        .testTarget(
            name: "FriendsServiceTests",
            dependencies: ["FriendsService"]
        ),
    ]
)