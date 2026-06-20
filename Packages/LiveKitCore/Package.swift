// swift-tools-version:5.8
import PackageDescription

let package = Package(
  name: "LiveKitCore",
  platforms: [.iOS(.v15)],
  products: [
    .library(name: "LiveKitCore", targets: ["LiveKitCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/livekit/client-sdk-swift.git", from: "2.6.1")
  ],
  targets: [
    .target(name: "LiveKitCore", dependencies: [
      .product(name: "LiveKit", package: "client-sdk-swift")
    ],
    path: "Sources/LiveKitCore")
  ]
) 