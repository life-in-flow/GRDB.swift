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
            url: "https://github.com/life-in-flow/GRDB.swift/releases/download/7.4.0/GRDB.xcframework.zip",
            checksum: "f88d304055b43f895ab8bbf9c6688f6c55bfbcd0b9a3eeed62b16a3229732892"
        ),
        .target(name: "_GRDBDummy")
    ]
)
