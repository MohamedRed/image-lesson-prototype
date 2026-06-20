// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "HealthService",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "HealthService",
            targets: ["HealthService"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HealthService",
            dependencies: []),
        .testTarget(
            name: "HealthServiceTests",
            dependencies: ["HealthService"]),
    ]
)