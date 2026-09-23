import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Stores archive chat turns and the moments cited in each reply.
class Migration024ChatMessages implements SqliteMigration {
  @override
  int get version => 24;

  @override
  String get id => '024_chat_messages';

  static const table = 'chat_messages';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY NOT NULL,
        role TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        source_entry_ids TEXT NOT NULL DEFAULT '',
        sources_json TEXT NOT NULL DEFAULT '[]',
        cancelled INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_chat_messages_created
      ON $table(created_at)
    ''');
  }
}
