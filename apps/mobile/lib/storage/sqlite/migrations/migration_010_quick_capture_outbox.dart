import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Drift-backed queue for home-screen / widget quick captures.
class Migration010QuickCaptureOutbox implements SqliteMigration {
  @override
  int get version => 10;

  @override
  String get id => '010_quick_capture_outbox';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quick_capture_outbox (
        outbox_id TEXT PRIMARY KEY NOT NULL,
        capture_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_quick_capture_outbox_pending_created
      ON quick_capture_outbox(created_at ASC)
      WHERE status = 'pending'
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_quick_capture_outbox_capture_id
      ON quick_capture_outbox(capture_id)
      WHERE status IN ('pending', 'processing')
    ''');
  }
}
