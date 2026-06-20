// swift-tools-version: 5.9
import PackageDescription

let package = Package(
	name: "HomeServicesFeature",
	platforms: [
		.iOS(.v16)
	],
	products: [
		.library(
			name: "HomeServicesFeature",
			targets: ["HomeServicesFeature"])
	],
	dependencies: [
		.package(path: "../HomeServicesService")
	],
	targets: [
		.target(
			name: "HomeServicesFeature",
			dependencies: [
				"HomeServicesService"
			]
		),
		.testTarget(
			name: "HomeServicesFeatureTests",
			dependencies: ["HomeServicesFeature"]
		)
	]
)
