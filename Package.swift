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
            url: "https://github.com/life-in-flow/GRDB.swift/releases/download/7.3.0/GRDB.xcframework.zip",
            checksum: "fc5516534808533df7be8d1c569ca13b963109c43ccc1d2a855189463df87537"
        ),
        .target(name: "_GRDBDummy")
    ]
)
