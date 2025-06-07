#!/bin/bash
set -euo pipefail

# This script builds GRDB with SQLCipher and packages it as an XCFramework
# The resulting archive can be used as a Swift Package binary target.

GRDB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="$(mktemp -d)"
SQLCIPHER_DIR="$WORKDIR/sqlcipher"
PATCH_FILE="$GRDB_DIR/Scripts/sqlcipher_xcodeproj.patch"
XCFRAMEWORK_DIR="$GRDB_DIR/SQLCipher"
XCFRAMEWORK="$XCFRAMEWORK_DIR/GRDB_SQLCipher.xcframework"
ZIPFILE="$XCFRAMEWORK_DIR/GRDB_SQLCipher.xcframework.zip"

mkdir -p "$XCFRAMEWORK_DIR"

clone_sqlcipher() {
    echo "Cloning SQLCipher..."
    git clone --depth 1 https://github.com/sqlcipher/sqlcipher.git "$SQLCIPHER_DIR" >/dev/null
}

build_sqlcipher() {
    echo "Building SQLCipher amalgamation..."
    pushd "$SQLCIPHER_DIR" >/dev/null
    ./configure >/dev/null
    make -j"$(sysctl -n hw.ncpu 2>/dev/null || echo 1)" sqlite3.c >/dev/null
    popd >/dev/null
    mkdir -p "$GRDB_DIR/SQLCipher"
    echo "#include <sys/param.h>" > "$GRDB_DIR/SQLCipher/sqlite3.c"
    cat "$SQLCIPHER_DIR/sqlite3.c" >> "$GRDB_DIR/SQLCipher/sqlite3.c"
    cp "$SQLCIPHER_DIR/sqlite3.h" "$GRDB_DIR/SQLCipher/sqlite3.h"
}

patch_project() {
    echo "Patching Xcode project..."
    patch -s -p1 -d "$GRDB_DIR" < "$PATCH_FILE"
}

archive_build() {
    local platform="$1"
    local archivePath="$2"
    xcodebuild archive \
        -project "$GRDB_DIR/GRDB.xcodeproj" \
        -scheme GRDB \
        -destination "generic/platform=$platform" \
        -archivePath "$archivePath" \
        -derivedDataPath "$WORKDIR/DerivedData" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO ONLY_ACTIVE_ARCH=NO >/dev/null
}

build_xcframework() {
    echo "Building XCFramework..."
    rm -rf "$XCFRAMEWORK" "$ZIPFILE" "$WORKDIR/DerivedData" "$WORKDIR/Archives"
    mkdir -p "$WORKDIR/Archives"
    archive_build "iOS" "$WORKDIR/Archives/GRDB-iOS"
    archive_build "iOS Simulator" "$WORKDIR/Archives/GRDB-iOS-Simulator"
    archive_build "macOS" "$WORKDIR/Archives/GRDB-macOS"
    xcodebuild -create-xcframework \
        -archive "$WORKDIR/Archives/GRDB-iOS.xcarchive" -framework GRDB.framework \
        -archive "$WORKDIR/Archives/GRDB-iOS-Simulator.xcarchive" -framework GRDB.framework \
        -archive "$WORKDIR/Archives/GRDB-macOS.xcarchive" -framework GRDB.framework \
        -output "$XCFRAMEWORK" >/dev/null
    ditto -c -k --keepParent "$XCFRAMEWORK" "$ZIPFILE"
}

compute_checksum() {
    swift package compute-checksum "$ZIPFILE"
}

clone_sqlcipher
build_sqlcipher
patch_project
build_xcframework
checksum=$(compute_checksum)

echo "\nCreated $ZIPFILE"
echo "Swift Package checksum: $checksum"

