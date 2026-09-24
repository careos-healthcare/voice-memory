import 'dart:io';

import 'package:archiveme_mobile/core/diagnostics/database_health_service.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:sqflite/sqflite.dart';

/// Applies numbered schema scripts from `PRAGMA user_version`.
///
/// Scripts at [additiveFromVersion] and later may only add tables and columns.
/// cr-sqlite keeps replication metadata on the original table, so a migration
/// must not rebuild one. A column added to an existing table is nullable or
/// carries a DEFAULT so an older mesh peer can omit it.
class MigrationManager {
  MigrationManager({
    List<SqliteMigration>? migrations,
    this.additiveFromVersion = 29,
  }) : _registry = SqliteMigrationRegistry(migrations);

  /// Legacy table name retained for imports from databases migrated before
  /// `user_version` tracking.
  static const legacySchemaMigrationsTable = 'schema_migrations';

  final SqliteMigrationRegistry _registry;

  /// First version whose statements are checked for additive SQL.
  final int additiveFromVersion;

  static int get latestVersion => SqliteMigrationRegistry.latestVersion;

  List<SqliteMigration> get migrations => _registry.migrations;

  Future<int> currentVersion(Database db) => _readUserVersion(db);

  /// Applies every migration newer than the stored `user_version`.
  Future<int> apply(Database db) => run(db);

  /// Applies every migration newer than the stored `user_version`.
  ///
  /// Returns the schema version after running (unchanged when already current).
  Future<int> run(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await _bootstrapLegacyVersion(db);

    var version = await _readUserVersion(db);
    final pending = _registry.pendingAfter(version);
    await _prepareForSchemaChange(db, pending);

    for (final migration in pending) {
      await _applyMigration(db, migration);
      version = migration.version;
    }

    return version;
  }

  /// Applies migrations sequentially until [targetVersion] is reached.
  Future<int> runToVersion(Database db, int targetVersion) async {
    if (targetVersion < 0) {
      throw ArgumentError.value(
        targetVersion,
        'targetVersion',
        'must be >= 0',
      );
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
    await _prepareForSchemaChange(db, pending);

    for (final migration in pending) {
      await _applyMigration(db, migration);
      version = migration.version;
    }

    return version;
  }

  /// Rejects destructive schema SQL and non-nullable added columns.
  static void assertAdditive(String sql) {
    final source = _withoutComments(sql);
    final folded = source.toUpperCase();
    if (RegExp(r'\bDROP\s+COLUMN\b').hasMatch(folded) ||
        RegExp(r'\bRENAME\s+COLUMN\b').hasMatch(folded) ||
        RegExp(r'\bDROP\s+TABLE\b').hasMatch(folded)) {
      throw StateError('Migration script is not additive: $sql');
    }
    _assertAddedColumnIsCompatible(source);
  }

  static void _assertAddedColumnIsCompatible(String sql) {
    final match = RegExp(
      r'ADD\s+COLUMN\s+\S+\s+(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(sql.trim());
    if (match == null) return;
    final definition = match.group(1)!.toUpperCase();
    final notNull = RegExp(r'\bNOT\s+NULL\b').hasMatch(definition);
    final hasDefault = RegExp(r'\bDEFAULT\b').hasMatch(definition);
    if (notNull && !hasDefault) {
      throw StateError(
        'Added column must be nullable or declare a DEFAULT: $sql',
      );
    }
  }

  static String _withoutComments(String sql) {
    return sql
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .replaceAll(RegExp(r'--[^\n]*'), ' ');
  }

  Future<void> _prepareForSchemaChange(
    Database db,
    Iterable<SqliteMigration> pending,
  ) async {
    final health = DatabaseHealthService();
    try {
      DatabaseHealthService.lastReport = await health.checkOpen(db);
    } on Object {
      DatabaseHealthService.lastReport = const DatabaseHealthReport.failed();
    }
    if (pending.isEmpty) return;
    try {
      await health.retainRollingBackup(File(db.path));
    } on Object {
      return;
    }
  }

  Future<void> _applyMigration(Database db, SqliteMigration migration) async {
    await db.transaction((txn) async {
      final executor = migration.version >= additiveFromVersion
          ? AdditiveMigrationExecutor(txn)
          : txn;
      await migration.up(executor);
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

/// Forwards SQL and rejects destructive statements before they reach SQLite.
class AdditiveMigrationExecutor implements DatabaseExecutor {
  AdditiveMigrationExecutor(this._inner);

  final DatabaseExecutor _inner;

  void _guard(String sql) => MigrationManager.assertAdditive(sql);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    _guard(sql);
    return _inner.execute(sql, arguments);
  }

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) {
    _guard(sql);
    return _inner.rawInsert(sql, arguments);
  }

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) {
    _guard(sql);
    return _inner.rawUpdate(sql, arguments);
  }

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) {
    _guard(sql);
    return _inner.rawDelete(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    _guard(sql);
    return _inner.rawQuery(sql, arguments);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    String? nullColumnHack,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _inner.insert(
      table,
      values,
      nullColumnHack: nullColumnHack,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _inner.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<QueryCursor> rawQueryCursor(
    String sql,
    List<Object?>? arguments, {
    int? bufferSize,
  }) {
    _guard(sql);
    return _inner.rawQueryCursor(sql, arguments, bufferSize: bufferSize);
  }

  @override
  Future<QueryCursor> queryCursor(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
    int? bufferSize,
  }) {
    return _inner.queryCursor(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
      bufferSize: bufferSize,
    );
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
    ConflictAlgorithm? conflictAlgorithm,
  }) {
    return _inner.update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _inner.delete(table, where: where, whereArgs: whereArgs);
  }

  @override
  Batch batch() => _inner.batch();

  @override
  Database get database => _inner.database;
}
