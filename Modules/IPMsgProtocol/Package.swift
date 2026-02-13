// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IPMsgProtocol",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "IPMsgProtocol",
            targets: ["IPMsgProtocol"]
        ),
    ],
    targets: [
        .target(
            name: "IPMsgProtocol",
            dependencies: []
        ),
        .testTarget(
            name: "IPMsgProtocolTests",
            dependencies: ["IPMsgProtocol"]
        ),
    ]
)
