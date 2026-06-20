// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MealPlanningService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MealPlanningService",
            targets: ["MealPlanningService"]
        ),
    ],
    dependencies: [
        // Firebase dependencies
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0"),
    ],
    targets: [
        .target(
            name: "MealPlanningService",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
            ]
        ),
        .testTarget(
            name: "MealPlanningServiceTests",
            dependencies: ["MealPlanningService"]
        ),
    ]
)