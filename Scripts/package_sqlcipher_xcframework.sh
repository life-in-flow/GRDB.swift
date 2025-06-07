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
SQLCIPHER_SWIFT_FLAGS="-D SWIFT_PACKAGE -D SQLITE_HAS_CODEC -D GRDBCIPHER -D SQLITE_ENABLE_FTS5"
SQLCIPHER_DEFINES="SQLITE_HAS_CODEC=1 GRDBCIPHER=1 SQLITE_ENABLE_FTS5=1"
SQLCIPHER_CFLAGS="-DSQLITE_HAS_CODEC -DGRDBCIPHER -DSQLITE_ENABLE_FTS5"

IMPORT_FILES=""

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
    echo "#include <sys/param.h>" > "$GRDB_DIR/GRDB/sqlite3.c"
    cat "$SQLCIPHER_DIR/sqlite3.c" >> "$GRDB_DIR/GRDB/sqlite3.c"
    cp "$SQLCIPHER_DIR/sqlite3.h" "$GRDB_DIR/GRDB/sqlite3.h"
}

patch_project() {
    echo "Patching Xcode project..."
    patch -N -s -p1 -d "$GRDB_DIR" < "$PATCH_FILE" || true
}

comment_imports() {
    IMPORT_FILES=$(grep -rl "import SQLCipher" "$GRDB_DIR/GRDB" || true)
    for f in $IMPORT_FILES; do
        sed -i.bak 's/^import SQLCipher/\/\/ import SQLCipher/' "$f"
    done
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
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES SKIP_INSTALL=NO ONLY_ACTIVE_ARCH=NO \
        OTHER_SWIFT_FLAGS="$SQLCIPHER_SWIFT_FLAGS" \
        OTHER_CFLAGS="$SQLCIPHER_CFLAGS" \
        GCC_PREPROCESSOR_DEFINITIONS="$SQLCIPHER_DEFINES" >/dev/null
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

cleanup() {
    patch -R -s -p1 -d "$GRDB_DIR" < "$PATCH_FILE" || true
    git -C "$GRDB_DIR" checkout -- ${IMPORT_FILES:-}
    rm -f "$GRDB_DIR"/GRDB/*.bak >/dev/null 2>&1 || true
    rm -f "$GRDB_DIR/GRDB/sqlite3.c" "$GRDB_DIR/GRDB/sqlite3.h"
}

trap cleanup EXIT

clone_sqlcipher
build_sqlcipher
patch_project
comment_imports
build_xcframework
checksum=$(compute_checksum)

echo "\nCreated $ZIPFILE"
echo "Swift Package checksum: $checksum"

