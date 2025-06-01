#!/bin/bash

set -e

# Script to build GRDB as a binary target with SQLCipher support
# while keeping other modules like GRDBSQLite as source targets

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKDIR="${SCRIPT_DIR}/build_temp"
SQLCIPHER_DIR="${WORKDIR}/sqlcipher"
XCFRAMEWORK_OUTPUT="${SCRIPT_DIR}/GRDB.xcframework"
XCFRAMEWORK_ZIP="${SCRIPT_DIR}/GRDB.xcframework.zip"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "${WORKDIR}"
}

# Error handler
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    cleanup
    exit 1
}

# Create working directory
mkdir -p "${WORKDIR}"

echo -e "${GREEN}Building GRDB binary target with SQLCipher support${NC}"
echo "Working directory: ${WORKDIR}"

# Step 1: Clone SQLCipher
echo -e "\n${GREEN}Step 1: Cloning SQLCipher...${NC}"
if [[ -d "${SQLCIPHER_DIR}" ]]; then
    rm -rf "${SQLCIPHER_DIR}"
fi

git clone https://github.com/sqlcipher/sqlcipher.git "${SQLCIPHER_DIR}" >/dev/null 2>&1 || error_exit "Failed to clone SQLCipher"

cd "${SQLCIPHER_DIR}"
# Get the latest stable tag
SQLCIPHER_TAG=$(git describe --tags --abbrev=0)
git checkout "${SQLCIPHER_TAG}" >/dev/null 2>&1
cd "${SCRIPT_DIR}"
echo "Using SQLCipher version: ${SQLCIPHER_TAG}"

# Step 2: Build SQLCipher
echo -e "\n${GREEN}Step 2: Building SQLCipher...${NC}"
cd "${SQLCIPHER_DIR}"

# Configure SQLCipher with CommonCrypto
./configure CFLAGS="-DSQLCIPHER_CRYPTO_CC" >/dev/null 2>&1 || error_exit "Failed to configure SQLCipher"

# Build SQLCipher
make -j$(sysctl -n hw.ncpu) sqlite3.c >/dev/null 2>&1 || error_exit "Failed to build SQLCipher"
cd "${SCRIPT_DIR}"

# Step 3: Copy SQLCipher files to GRDB
echo -e "\n${GREEN}Step 3: Integrating SQLCipher into GRDB...${NC}"
GRDB_DIR="${SCRIPT_DIR}/GRDB"

# Backup original sqlite files if they exist
if [[ -f "${GRDB_DIR}/sqlite3.h" ]]; then
    mv "${GRDB_DIR}/sqlite3.h" "${GRDB_DIR}/sqlite3.h.backup"
fi
if [[ -f "${GRDB_DIR}/sqlite3.c" ]]; then
    mv "${GRDB_DIR}/sqlite3.c" "${GRDB_DIR}/sqlite3.c.backup"
fi

# Copy SQLCipher files
cp "${SQLCIPHER_DIR}/sqlite3.h" "${GRDB_DIR}/"
echo "#include <sys/param.h>" > "${GRDB_DIR}/sqlite3.c"
cat "${SQLCIPHER_DIR}/sqlite3.c" >> "${GRDB_DIR}/sqlite3.c"

# Step 4: Update Export.swift to be empty (required for the build)
echo "" > "${GRDB_DIR}/Export.swift"

# Step 5: Build XCFramework
echo -e "\n${GREEN}Step 4: Building XCFramework...${NC}"

# Clean previous builds
rm -rf "${XCFRAMEWORK_OUTPUT}" "${XCFRAMEWORK_ZIP}"
DERIVED_DATA="${WORKDIR}/DerivedData"
ARCHIVES_DIR="${WORKDIR}/archives"
mkdir -p "${ARCHIVES_DIR}"

# Function to build archive for a platform
build_archive() {
    local platform=$1
    local archive_path="${ARCHIVES_DIR}/GRDB-${platform// /-}.xcarchive"
    
    echo "  Building for ${platform}..."
    
    xcodebuild archive \
        -project "${SCRIPT_DIR}/GRDB.xcodeproj" \
        -scheme GRDB \
        -destination "generic/platform=${platform}" \
        -archivePath "${archive_path}" \
        -derivedDataPath "${DERIVED_DATA}" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        OTHER_SWIFT_FLAGS="-D GRDBSQLITE_INCLUDED" \
        SKIP_INSTALL=NO \
        ONLY_ACTIVE_ARCH=NO \
        -xcconfig "${SCRIPT_DIR}/build_assets/SQLCipher.xcconfig" \
        >/dev/null 2>&1 || error_exit "Failed to build archive for ${platform}"
}

# Build for all platforms
build_archive "macOS"
build_archive "iOS"
build_archive "iOS Simulator"

# Create XCFramework
echo -e "\n${GREEN}Step 5: Creating XCFramework...${NC}"
xcodebuild -create-xcframework \
    -archive "${ARCHIVES_DIR}/GRDB-macOS.xcarchive" -framework GRDB.framework \
    -archive "${ARCHIVES_DIR}/GRDB-iOS.xcarchive" -framework GRDB.framework \
    -archive "${ARCHIVES_DIR}/GRDB-iOS-Simulator.xcarchive" -framework GRDB.framework \
    -output "${XCFRAMEWORK_OUTPUT}" \
    >/dev/null 2>&1 || error_exit "Failed to create XCFramework"

# Step 6: Compress XCFramework
echo -e "\n${GREEN}Step 6: Compressing XCFramework...${NC}"
cd "${SCRIPT_DIR}"
ditto -c -k --keepParent --noextattr --norsrc "${XCFRAMEWORK_OUTPUT}" "${XCFRAMEWORK_ZIP}" || error_exit "Failed to compress XCFramework"

# Calculate checksum
CHECKSUM=$(swift package compute-checksum "${XCFRAMEWORK_ZIP}")
echo "XCFramework checksum: ${CHECKSUM}"

# Step 7: Create Sources directory structure for dummy target
echo -e "\n${GREEN}Step 7: Creating dummy target structure...${NC}"
mkdir -p "${SCRIPT_DIR}/Sources/_GRDBDummy"
echo "" > "${SCRIPT_DIR}/Sources/_GRDBDummy/_GRDBDummy.swift"

# Step 8: Update Package.swift
echo -e "\n${GREEN}Step 8: Creating updated Package.swift...${NC}"
cat > "${SCRIPT_DIR}/Package_binary.swift" << EOF
// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

var swiftSettings: [SwiftSetting] = [
    .define("SQLITE_ENABLE_FTS5"),
]
var dependencies: [PackageDescription.Package.Dependency] = []

// The SPI_BUILDER environment variable enables documentation building
if ProcessInfo.processInfo.environment["SPI_BUILDER"] == "1" {
    dependencies.append(.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"))
}

let package = Package(
    name: "GRDB",
    defaultLocalization: "en",
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
        // Binary target for GRDB with SQLCipher
        .binaryTarget(
            name: "GRDB",
            path: "./GRDB.xcframework"
        ),
        // GRDBSQLite remains as source target
        .systemLibrary(
            name: "GRDBSQLite",
            providers: [.apt(["libsqlite3-dev"])]),
        // Dummy target to satisfy SPM requirements
        .target(name: "_GRDBDummy"),
        // Test target
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
            swiftSettings: swiftSettings + [
                .swiftLanguageMode(.v5),
                .enableUpcomingFeature("InferSendableFromCaptures"),
                .enableUpcomingFeature("GlobalActorIsolatedTypesUsability"),
            ])
    ],
    swiftLanguageModes: [.v6]
)
EOF

# Cleanup
cleanup

echo -e "\n${GREEN}Build complete!${NC}"
echo -e "XCFramework location: ${XCFRAMEWORK_OUTPUT}"
echo -e "Compressed XCFramework: ${XCFRAMEWORK_ZIP}"
echo -e "Checksum: ${CHECKSUM}"
echo -e "\nTo use the binary target version:"
echo -e "  cp Package_binary.swift Package.swift"
echo -e "\nTo publish to GitHub releases:"
echo -e "  Upload ${XCFRAMEWORK_ZIP} to your GitHub release"
echo -e "  Update Package_binary.swift with the download URL and checksum" 