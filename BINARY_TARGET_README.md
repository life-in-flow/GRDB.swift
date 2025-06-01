# GRDB Binary Target with SQLCipher

This document explains how to build and use GRDB as a binary target with SQLCipher support while keeping other modules (like GRDBSQLite) as source targets.

## Overview

This approach allows you to:

- Use GRDB with SQLCipher encryption support
- Distribute GRDB as a pre-built binary (XCFramework)
- Keep GRDBSQLite and other modules as source targets
- Maintain compatibility with the upstream GRDB.swift API

## Prerequisites

- Xcode 14.0 or later
- macOS 12.0 or later
- Swift 5.7 or later
- Command line tools installed (`xcode-select --install`)

## Building the Binary Target

### Quick Start

1. Run the build script:

   ```bash
   ./build_binary_target.sh
   ```

2. Once complete, activate the binary target version:
   ```bash
   cp Package_binary.swift Package.swift
   ```

### What the Build Script Does

1. **Clones SQLCipher**: Downloads the latest stable version of SQLCipher
2. **Builds SQLCipher**: Compiles SQLCipher with CommonCrypto support (`SQLCIPHER_CRYPTO_CC`)
3. **Integrates with GRDB**: Replaces the standard SQLite with SQLCipher in GRDB
4. **Creates XCFramework**: Builds a universal framework for multiple platforms:
   - macOS
   - iOS
   - iOS Simulator
5. **Generates Package.swift**: Creates a new Package.swift that uses the binary target

### Build Output

After running the script, you'll have:

- `GRDB.xcframework/` - The built framework
- `GRDB.xcframework.zip` - Compressed framework for distribution
- `Package_binary.swift` - Updated Package.swift using the binary target
- `Sources/_GRDBDummy/` - Dummy target required by SPM

## Using the Binary Target

### Local Development

For local development, the generated `Package_binary.swift` uses a local path reference:

```swift
.binaryTarget(
    name: "GRDB",
    path: "./GRDB.xcframework"
)
```

### Remote Distribution

To distribute via GitHub releases:

1. Create a new release on GitHub
2. Upload `GRDB.xcframework.zip` as a release asset
3. Update `Package_binary.swift` with the download URL:

```swift
.binaryTarget(
    name: "GRDB",
    url: "https://github.com/YOUR_USERNAME/GRDB.swift/releases/download/VERSION/GRDB.xcframework.zip",
    checksum: "YOUR_CHECKSUM_HERE"
)
```

## Package Structure

The binary target Package.swift maintains:

- **GRDB** - Binary target with SQLCipher support
- **GRDBSQLite** - System library target (remains as source)
- **\_GRDBDummy** - Empty target to satisfy SPM requirements
- **GRDBTests** - Test target

## SQLCipher Configuration

The build uses these SQLCipher settings:

- **Encryption**: CommonCrypto (`SQLCIPHER_CRYPTO_CC`)
- **FTS5**: Enabled
- **Preupdate Hook**: Enabled
- **Security Framework**: Linked automatically

## Switching Between Source and Binary

### To use binary target:

```bash
cp Package_binary.swift Package.swift
```

### To return to source target:

```bash
git checkout Package.swift
```

## Updating SQLCipher or GRDB

To update to a new version:

1. For SQLCipher updates:

   - The script automatically uses the latest stable tag
   - To use a specific version, modify the script

2. For GRDB updates:
   - Merge/rebase from upstream GRDB.swift
   - Run the build script again

## Troubleshooting

### Build Failures

If the build fails:

1. Check Xcode command line tools: `xcode-select --install`
2. Verify the GRDB.xcodeproj opens correctly
3. Check build logs in `build_temp/Logs/`

### Missing sqlite3.h/sqlite3.c

The script handles adding these files automatically. If issues occur:

1. The script backs up original files to `.backup`
2. Check that SQLCipher built successfully
3. Verify files exist in `GRDB/` directory

### Framework Not Found

Ensure:

1. The XCFramework was built successfully
2. The path in Package.swift is correct
3. Clean your build folder and derived data

## Advanced Usage

### Custom SQLCipher Configuration

Edit `build_assets/SQLCipher.xcconfig` to modify:

- Compiler flags
- Preprocessor definitions
- Linker settings

### Platform-Specific Builds

Modify the `build_archive` function in the script to add/remove platforms.

### Continuous Integration

The script can be used in CI/CD pipelines:

```bash
./build_binary_target.sh
# Upload GRDB.xcframework.zip to your artifact storage
```

## Differences from Standard GRDB

When using the binary target with SQLCipher:

1. Database files are encrypted by default
2. You must provide a passphrase when opening databases
3. Additional SQLCipher-specific pragmas are available
4. Slightly different performance characteristics

## Example Usage

```swift
import GRDB

// Open an encrypted database
let dbQueue = try DatabaseQueue(path: "db.sqlite")
try dbQueue.write { db in
    // Set the encryption key
    try db.execute(sql: "PRAGMA key = 'your-secret-passphrase'")

    // Use GRDB as normal
    try db.create(table: "player") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("name", .text).notNull()
        t.column("score", .integer).notNull()
    }
}
```

## License

This binary target approach maintains the same license as GRDB.swift (MIT) and includes SQLCipher (BSD-style license).
