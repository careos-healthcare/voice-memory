import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'configure_sqlite_test_ffi.dart';

/// Utilities for automated SQLite migration unit tests.
class SqliteMigrationTestHarness {
  SqliteMigrationTestHarness({List<SqliteMigration>? migrations})
      : manager = SqliteMigrationManager(migrations: migrations);

  final SqliteMigrationManager manager;

  Future<Database> openEmpty({
    String path = inMemoryDatabasePath,
    bool encrypted = true,
  }) async {
    if (encrypted) {
      final password = SqliteDatabaseInitializer.testEncryptionPassword
          .replaceAll("'", "''");
      return databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          onConfigure: (db) async {
            await db.execute("PRAGMA key = '$password'");
            await db.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
    }

    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
  }

  /// Opens a database and applies migrations through [version].
  Future<Database> openAtVersion(int version) async {
    final db = await openEmpty();
    addTearDown(db.close);
    await manager.runToVersion(db, version);
    return db;
  }

  /// Opens a database with every registered migration applied.
  Future<Database> openLatest() async {
    final db = await openEmpty();
    addTearDown(db.close);
    await manager.run(db);
    return db;
  }

  Future<int> readUserVersion(Database db) => manager.currentVersion(db);

  Future<void> expectVersion(Database db, int expected) async {
    expect(await readUserVersion(db), expected);
  }

  Future<void> expectTableExists(
    Database db,
    String tableName, {
    bool exists = true,
  }) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    expect(rows.isNotEmpty, exists, reason: 'table $tableName');
  }

  /// Running migrations twice should not change schema version or fail.
  Future<void> expectIdempotent(Database db) async {
    final before = await readUserVersion(db);
    await manager.run(db);
    expect(await readUserVersion(db), before);
    await manager.run(db);
    expect(await readUserVersion(db), before);
  }
}

/// Initializes sqflite FFI for migration tests.
void configureSqliteMigrationTests() {
  configureSqliteTestFfi();
}
