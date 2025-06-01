#!/bin/bash

set -e

echo "Converting GRDB to use binary target..."

# 1. First build the binary if it doesn't exist
if [[ ! -f "GRDB.xcframework.zip" ]]; then
    echo "Building XCFramework first..."
    ./build_binary.sh
fi

# 2. Get the checksum
CHECKSUM=$(swift package compute-checksum GRDB.xcframework.zip)

# 3. Backup original Package.swift
cp Package.swift Package.swift.backup

# 4. Create the new Package.swift that replaces source GRDB with binary
cat > Package.swift << 'EOF'
// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
]
var cSettings: [CSetting] = []
var dependencies: [PackageDescription.Package.Dependency] = []

// Don't rely on those environment variables. They are ONLY testing conveniences:
// $ SQLITE_ENABLE_PREUPDATE_HOOK=1 make test_SPM
if ProcessInfo.processInfo.environment["SQLITE_ENABLE_PREUPDATE_HOOK"] == "1" {
    swiftSettings.append(.define("SQLITE_ENABLE_PREUPDATE_HOOK"))
    cSettings.append(.define("GRDB_SQLITE_ENABLE_PREUPDATE_HOOK"))
}

// The SPI_BUILDER environment variable enables documentation building
// on <https://swiftpackageindex.com/groue/GRDB.swift>. See
// <https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/issues/2122>
// for more information.
//
// SPI_BUILDER also enables the `make docs-localhost` command.
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

let package = Package(
    name: "GRDB",
    defaultLocalization: "en", // for tests
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v7),
    ],
    products: [
        .library(name: "GRDBSQLite", targets: ["GRDBSQLite"]),
        .library(name: "GRDB", targets: ["GRDB", "_GRDBDummy"]),
        .library(name: "GRDB-dynamic", type: .dynamic, targets: ["GRDB", "_GRDBDummy"]),
    ],
    dependencies: dependencies,
    targets: [
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        
        // GRDB is now a binary target with SQLCipher included
        .binaryTarget(
            name: "GRDB",
            url: "https://github.com/life-in-flow/GRDB.swift/releases/download/PLACEHOLDER_VERSION/GRDB.xcframework.zip",
            checksum: "PLACEHOLDER_CHECKSUM"
        ),
        
        // Dummy target required for binary targets
        .target(name: "_GRDBDummy"),
        
        .testTarget(
            name: "GRDBTests",
            dependencies: ["GRDB"],
            path: "Tests",
            exclude: [
                "CocoaPods",
                "Crash",
                "CustomSQLite",
                "GRDBManualInstall",
                "GRDBTests/getThreadsCount.c",
                "Info.plist",
                "Performance",
                "SPM",
                "Swift6Migration",
                "generatePerformanceReport.rb",
                "parsePerformanceTests.rb",
            ],
            resources: [
                .copy("GRDBTests/Betty.jpeg"),
                .copy("GRDBTests/InflectionsTests.json"),
                .copy("GRDBTests/Issue1383.sqlite"),
            ],
            cSettings: cSettings,
            swiftSettings: swiftSettings + [
                // Tests still use the Swift 5 language mode.
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
EOF

# 5. Update with actual checksum
sed -i '' "s/PLACEHOLDER_CHECKSUM/${CHECKSUM}/" Package.swift

# 6. Create dummy target if it doesn't exist
mkdir -p Sources/_GRDBDummy
echo "" > Sources/_GRDBDummy/_GRDBDummy.swift

echo ""
echo "✅ Package.swift updated to use binary target!"
echo ""
echo "Next steps:"
echo "1. Update PLACEHOLDER_VERSION in Package.swift with your release version"
echo "2. Commit and push these changes"
echo "3. Create a GitHub release and upload GRDB.xcframework.zip"
echo "4. The URL in Package.swift should match your release URL"
echo ""
echo "To revert: cp Package.swift.backup Package.swift" 