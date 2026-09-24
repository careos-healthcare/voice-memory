import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local change log for mesh merges, plus per-device relationship weights.
class Migration027SyncChangelog implements SqliteMigration {
  @override
  int get version => 27;

  @override
  String get id => '027_sync_changelog';

  static const changelogTable = 'sync_changelog';
  static const weightReplicasTable = 'sync_weight_replicas';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $changelogTable (
        entity_table TEXT NOT NULL,
        record_id TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        PRIMARY KEY (entity_table, record_id, device_id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_changelog_updated
      ON $changelogTable(updated_at)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $weightReplicasTable (
        relationship_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        weight REAL NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (relationship_id, device_id)
      )
    ''');
  }
}
