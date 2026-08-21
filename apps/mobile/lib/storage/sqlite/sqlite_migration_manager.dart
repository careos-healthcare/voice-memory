import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:sqflite/sqflite.dart';

/// Applies versioned SQLite schema migrations tracked via `PRAGMA user_version`.
class SqliteMigrationManager {
  SqliteMigrationManager({List<SqliteMigration>? migrations})
      : _registry = SqliteMigrationRegistry(migrations);

  /// Legacy table name retained for imports from databases migrated before
  /// `user_version` tracking.
  static const legacySchemaMigrationsTable = 'schema_migrations';

  final SqliteMigrationRegistry _registry;

  static int get latestVersion => SqliteMigrationRegistry.latestVersion;

  List<SqliteMigration> get migrations => _registry.migrations;

  Future<int> currentVersion(Database db) => _readUserVersion(db);

  /// Applies every migration newer than the stored `user_version`.
  ///
  /// Returns the schema version after running (unchanged when already current).
  Future<int> run(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await _bootstrapLegacyVersion(db);

    var version = await _readUserVersion(db);
    final pending = _registry.pendingAfter(version);

    for (final migration in pending) {
      await _applyMigration(db, migration);
      version = migration.version;
    }

    return version;
  }

  /// Applies migrations sequentially until [targetVersion] is reached.
  Future<int> runToVersion(Database db, int targetVersion) async {
    if (targetVersion < 0) {
      throw ArgumentError.value(targetVersion, 'targetVersion', 'must be >= 0');
    }

    await db.execute('PRAGMA foreign_keys = ON');
    await _bootstrapLegacyVersion(db);

    var version = await _readUserVersion(db);
    if (targetVersion <= version) {
      return version;
    }

    final pending = _registry
        .pendingAfter(version)
        .where((migration) => migration.version <= targetVersion);

    for (final migration in pending) {
      await _applyMigration(db, migration);
      version = migration.version;
    }

    return version;
  }

  Future<void> _applyMigration(Database db, SqliteMigration migration) async {
    await db.transaction((txn) async {
      await migration.up(txn);
      await txn.execute('PRAGMA user_version = ${migration.version}');
    });
  }

  Future<void> _bootstrapLegacyVersion(Database db) async {
    if (!await _tableExists(db, legacySchemaMigrationsTable)) {
      return;
    }

    final rows = await db.query(
      legacySchemaMigrationsTable,
      columns: ['version'],
    );

    if (rows.isNotEmpty) {
      final legacyVersion = rows
          .map((row) => row['version'])
          .whereType<int>()
          .fold<int>(0, (max, value) => value > max ? value : max);
      if (legacyVersion > 0) {
        final userVersion = await _readUserVersion(db);
        if (legacyVersion > userVersion) {
          await db.execute('PRAGMA user_version = $legacyVersion');
        }
      }
    }

    await db.execute('DROP TABLE IF EXISTS $legacySchemaMigrationsTable');
  }

  static Future<int> _readUserVersion(Database db) async {
    final rows = await db.rawQuery('PRAGMA user_version');
    if (rows.isEmpty) {
      return 0;
    }
    final value = rows.first['user_version'];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  static Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }
}
