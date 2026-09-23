import 'package:archiveme_mobile/storage/sqlite/migration_manager.dart';

/// Applies versioned SQLite schema migrations tracked via `PRAGMA user_version`.
class SqliteMigrationManager extends MigrationManager {
  SqliteMigrationManager({
    super.migrations,
    super.additiveFromVersion,
  });

  static const legacySchemaMigrationsTable =
      MigrationManager.legacySchemaMigrationsTable;

  static int get latestVersion => MigrationManager.latestVersion;
}
