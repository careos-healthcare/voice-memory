import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Remembers creates, edits, and deletes that have not reached the cloud.
class Migration023SyncDirty implements SqliteMigration {
  @override
  int get version => 23;

  @override
  String get id => '023_sync_dirty';

  static const column = 'sync_dirty';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await _addColumn(db, 'journal_entries');
    await _addColumn(db, 'deleted_entries');
  }

  Future<void> _addColumn(DatabaseExecutor db, String table) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    if (info.isEmpty) return;
    if (info.any((row) => row['name'] == column)) return;
    await db.execute(
      'ALTER TABLE $table ADD COLUMN $column INTEGER NOT NULL DEFAULT 0',
    );
  }
}
