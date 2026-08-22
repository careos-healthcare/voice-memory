import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Adds scheduled retry timestamps to the encrypted sync outbox queue.
class Migration012SyncOutboxRetrySchedule implements SqliteMigration {
  @override
  int get version => 12;

  @override
  String get id => '012_sync_outbox_retry_schedule';

  static const table = 'sync_outbox';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final hasNextRetryAt = columns.any(
      (column) => column['name'] == 'next_retry_at',
    );
    if (!hasNextRetryAt) {
      await db.execute('''
        ALTER TABLE $table
        ADD COLUMN next_retry_at INTEGER
      ''');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_pending_retry
      ON $table(next_retry_at ASC)
      WHERE status = 'pending'
    ''');
  }
}
