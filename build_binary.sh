#!/bin/bash

set -e

# Minimal script to build GRDB.xcframework with SQLCipher

echo "Building GRDB XCFramework with SQLCipher..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. Build SQLCipher if needed
if [[ ! -f "GRDB/sqlite3.c" ]]; then
    echo "Building SQLCipher..."
    rm -rf /tmp/sqlcipher
    git clone https://github.com/sqlcipher/sqlcipher.git /tmp/sqlcipher >/dev/null 2>&1
    cd /tmp/sqlcipher
    git checkout v4.9.0 >/dev/null 2>&1
    ./configure CFLAGS="-DSQLCIPHER_CRYPTO_CC" >/dev/null 2>&1
    make -j$(sysctl -n hw.ncpu) sqlite3.c >/dev/null 2>&1
    cd -
    
    cp /tmp/sqlcipher/sqlite3.h GRDB/
    echo "#include <sys/param.h>" > GRDB/sqlite3.c
    cat /tmp/sqlcipher/sqlite3.c >> GRDB/sqlite3.c
fi

# 2. Comment out imports
find GRDB -name "*.swift" -type f -exec sed -i '' 's/import SQLCipher/\/\/import SQLCipher/g' {} +
find GRDB -name "*.swift" -type f -exec sed -i '' 's/import SQLite3/\/\/import SQLite3/g' {} +

# 3. Clear Export.swift
echo "" > GRDB/Export.swift

# 4. Build XCFramework
rm -rf GRDB.xcframework /tmp/grdb-archives

for PLATFORM in "macOS" "iOS" "iOS Simulator"; do
    echo "Building for ${PLATFORM}..."
    xcodebuild archive \
        -project GRDB.xcodeproj \
        -scheme GRDB \
        -destination "generic/platform=${PLATFORM}" \
        -archivePath "/tmp/grdb-archives/GRDB-${PLATFORM// /-}.xcarchive" \
        BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
        SKIP_INSTALL=NO \
        ONLY_ACTIVE_ARCH=NO \
        -xcconfig "build_assets/SQLCipher.xcconfig"
done

xcodebuild -create-xcframework \
    -archive "/tmp/grdb-archives/GRDB-macOS.xcarchive" -framework GRDB.framework \
    -archive "/tmp/grdb-archives/GRDB-iOS.xcarchive" -framework GRDB.framework \
    -archive "/tmp/grdb-archives/GRDB-iOS-Simulator.xcarchive" -framework GRDB.framework \
    -output GRDB.xcframework \
    >/dev/null 2>&1

# 5. Zip
echo "Creating XCFramework zip..."
zip -r --symlinks GRDB.xcframework.zip GRDB.xcframework

echo "✅ Binary build complete!"
echo ""
echo "Created: GRDB.xcframework.zip"
echo ""
echo "To use the binary target in Package.swift:"
echo ".binaryTarget("
echo "  name: \"GRDB\","
echo "  path: \"GRDB.xcframework.zip\""
echo ")" 