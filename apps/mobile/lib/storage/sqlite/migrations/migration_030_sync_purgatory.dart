import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local holding table for cr-sqlite deltas whose parent row has not arrived.
///
/// This is a normal SQLite table. It is not registered with cr-sqlite, so it
/// is never a conflict-free replicated relation.
class Migration030SyncPurgatory implements SqliteMigration {
  @override
  int get version => 30;

  @override
  String get id => '030_sync_purgatory';

  static const table = 'sync_purgatory';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_table TEXT NOT NULL,
        pk TEXT NOT NULL,
        cid TEXT NOT NULL DEFAULT '',
        val TEXT,
        col_version INTEGER NOT NULL DEFAULT 0,
        db_version INTEGER NOT NULL DEFAULT 0,
        site_id TEXT NOT NULL DEFAULT '',
        causal_length INTEGER NOT NULL DEFAULT 0,
        seq INTEGER,
        packet_json TEXT NOT NULL,
        parked_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_purgatory_packet
      ON $table(target_table, pk, cid, site_id, db_version)
    ''');
  }
}
