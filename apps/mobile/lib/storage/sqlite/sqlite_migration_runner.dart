import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:sqflite/sqflite.dart';

/// Applies pending SQLite migrations in ascending version order.
///
/// Prefer [SqliteMigrationManager], which tracks schema versions with
/// `PRAGMA user_version`.
@Deprecated('Use SqliteMigrationManager instead.')
class SqliteMigrationRunner {
  SqliteMigrationRunner({List<SqliteMigration>? migrations})
      : _manager = SqliteMigrationManager(migrations: migrations);

  static const schemaMigrationsTable =
      SqliteMigrationManager.legacySchemaMigrationsTable;

  final SqliteMigrationManager _manager;

  Future<void> run(Database db) async {
    await _manager.run(db);
  }
}
