// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluxQModels",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "FluxQModels",
            targets: ["FluxQModels"]),
    ],
    targets: [
        .target(
            name: "FluxQModels"),
        .testTarget(
            name: "FluxQModelsTests",
            dependencies: ["FluxQModels"]),
    ]
)
