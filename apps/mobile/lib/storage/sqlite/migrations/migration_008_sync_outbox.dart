import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Offline-first encrypted sync outbox — local SQLite is the source of truth.
class Migration008SyncOutbox implements SqliteMigration {
  @override
  int get version => 8;

  @override
  String get id => '008_sync_outbox';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        outbox_id TEXT PRIMARY KEY NOT NULL,
        blob_id TEXT NOT NULL,
        blob_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending_created
      ON sync_outbox(created_at ASC)
      WHERE status = 'pending'
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_sync_outbox_pending_blob
      ON sync_outbox(blob_id, blob_type)
      WHERE status IN ('pending', 'in_flight')
    ''');
  }
}
