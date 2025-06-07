// This file exists to ensure GRDBSQLite target has Swift sources to compile
// The actual SQLite functionality is provided by the swift-sqlcipher package

// Re-export SQLCipher so that importing GRDBSQLite provides access to SQLite functions
@_exported import SQLCipher 