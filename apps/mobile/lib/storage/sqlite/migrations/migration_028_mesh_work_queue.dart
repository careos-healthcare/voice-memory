import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Chronological queue for mesh sync envelopes and local embedding jobs.
class Migration028MeshWorkQueue implements SqliteMigration {
  @override
  int get version => 28;

  @override
  String get id => '028_mesh_work_queue';

  static const queueTable = 'background_task_queue';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $queueTable (
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        entry_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        status TEXT NOT NULL,
        enqueued_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
    final info = await db.rawQuery('PRAGMA table_info($queueTable)');
    final columns = <String>{
      for (final row in info) '${row['name']}',
    };
    if (!columns.contains('enqueued_at')) {
      await db.execute(
        'ALTER TABLE $queueTable ADD COLUMN enqueued_at INTEGER NOT NULL DEFAULT 0',
      );
    }
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_background_task_queue_pending
      ON $queueTable(enqueued_at ASC, id ASC)
    ''');
  }
}
