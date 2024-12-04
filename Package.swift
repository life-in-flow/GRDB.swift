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
            url: "https://github.com/life-in-flow/GRDB.swift/releases/download/1.0.1/GRDB.xcframework.zip",
            checksum: "c59f3d8c3e7d6a6d1eef3d89fa7ff304c7125404b7f41c5f51f0e873fad419e3"
        ),
        .target(name: "_GRDBDummy")
    ]
)
