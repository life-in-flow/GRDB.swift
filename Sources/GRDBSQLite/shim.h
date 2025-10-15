#include <sqlite3.h>

// Expose APIs that are missing from system <sqlite3.h>
#ifdef GRDB_SQLITE_ENABLE_PREUPDATE_HOOK
SQLITE_API void *sqlite3_preupdate_hook(
    sqlite3 *db,
    void (*xPreUpdate)(
        void *pCtx,
        sqlite3 *db,
        int op,
        char const *zDb,
        char const *zName,
        sqlite3_int64 iKey1,
        sqlite3_int64 iKey2
        ),
    void *);
SQLITE_API int sqlite3_preupdate_old(sqlite3 *, int, sqlite3_value **);
SQLITE_API int sqlite3_preupdate_count(sqlite3 *);
SQLITE_API int sqlite3_preupdate_depth(sqlite3 *);
SQLITE_API int sqlite3_preupdate_new(sqlite3 *, int, sqlite3_value **);
#endif /* GRDB_SQLITE_ENABLE_PREUPDATE_HOOK */
