import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Stores weekly and monthly life memos.
class Migration022LifeMemos implements SqliteMigration {
  @override
  int get version => 22;

  @override
  String get id => '022_life_memos';

  static const table = 'life_memos';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        period TEXT NOT NULL,
        window_start INTEGER NOT NULL,
        window_end INTEGER NOT NULL,
        title TEXT NOT NULL,
        markdown TEXT NOT NULL,
        evidence_entry_ids TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }
}
