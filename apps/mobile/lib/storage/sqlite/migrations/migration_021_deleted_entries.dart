import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Remembers a deleted journal entry so other devices can learn about it.
class Migration021DeletedEntries implements SqliteMigration {
  @override
  int get version => 21;

  @override
  String get id => '021_deleted_entries';

  static const table = 'deleted_entries';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY NOT NULL,
        deleted_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL
      )
    ''');
  }
}
