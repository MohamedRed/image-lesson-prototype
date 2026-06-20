// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MealPlanningFeature",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "MealPlanningFeature",
            targets: ["MealPlanningFeature"]
        ),
    ],
    dependencies: [
        .package(path: "../MealPlanningService"),
    ],
    targets: [
        .target(
            name: "MealPlanningFeature",
            dependencies: [
                "MealPlanningService"
            ]
        ),
        .testTarget(
            name: "MealPlanningFeatureTests",
            dependencies: ["MealPlanningFeature"]
        ),
    ]
)