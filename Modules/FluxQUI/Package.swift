// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluxQUI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "FluxQUI",
            targets: ["FluxQUI"]),
    ],
    targets: [
        .target(
            name: "FluxQUI"),
        .testTarget(
            name: "FluxQUITests",
            dependencies: ["FluxQUI"]),
    ]
)
