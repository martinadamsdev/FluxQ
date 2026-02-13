// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluxQServices",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "FluxQServices",
            targets: ["FluxQServices"]),
    ],
    dependencies: [
        .package(path: "../FluxQModels"),
        .package(path: "../IPMsgProtocol")
    ],
    targets: [
        .target(
            name: "FluxQServices",
            dependencies: [
                "FluxQModels",
                "IPMsgProtocol"
            ]),
        .testTarget(
            name: "FluxQServicesTests",
            dependencies: ["FluxQServices"]),
    ]
)
