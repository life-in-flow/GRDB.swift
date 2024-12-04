// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GRDB",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(name: "GRDB", targets: ["GRDB", "_GRDBDummy"]),
    ],
    targets: [
        .binaryTarget(
            name: "GRDB",
            url: "https://github.com/life-in-flow/GRDB.swift/releases/download/1.0.2/GRDB.xcframework.zip",
            checksum: "49b613b7ec661f605081728e62aff67d520d4b54c5116a2522f72ecbde04a302"
        ),
        .target(name: "_GRDBDummy")
    ]
)
