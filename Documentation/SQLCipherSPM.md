# Using SQLCipher with Swift Package Manager

GRDB ships with the system SQLite library. If you want to use SQLCipher, you can
build an XCFramework that embeds SQLCipher and use it as a binary target in your
project.

1. Run the following script from the root of GRDB to build `GRDB_SQLCipher.xcframework`:

   ```sh
   ./Scripts/package_sqlcipher_xcframework.sh
   ```

   The script downloads SQLCipher, compiles the amalgamation, patches the Xcode
   project, and creates `SQLCipher/GRDB_SQLCipher.xcframework.zip`.
   It also prints the Swift Package Manager checksum for the archive.

2. In your own package manifest, declare a binary target that points at the zip
   archive and use it instead of the regular `GRDB` target. Use the checksum
   printed by the script.

   ```swift
   .binaryTarget(
       name: "GRDB",
       path: "path/to/GRDB.swift/SQLCipher/GRDB_SQLCipher.xcframework.zip"
   ),
   ```

   You can then depend on the `GRDB` library as usual. The XCFramework contains
   both the `GRDB` Swift module and the `GRDBSQLite` C module compiled with
   SQLCipher.

This approach mirrors the one used by DuckDuckGo's fork of GRDB.swift which
packages an XCFramework for distribution.
