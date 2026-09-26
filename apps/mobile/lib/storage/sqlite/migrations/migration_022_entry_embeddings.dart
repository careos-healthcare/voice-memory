import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// On-device sentence vectors, plus labels and entries hidden from memory.
class Migration022EntryEmbeddings implements SqliteMigration {
  @override
  int get version => 22;

  @override
  String get id => '022_entry_embeddings';

  static const embeddingsTable = 'entry_embeddings';
  static const hiddenEntriesTable = 'memory_hidden_entries';
  static const hiddenLabelsTable = 'memory_hidden_labels';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $embeddingsTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        vector BLOB NOT NULL,
        model_version TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $hiddenEntriesTable (
        entry_id TEXT PRIMARY KEY NOT NULL,
        hidden_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $hiddenLabelsTable (
        label TEXT PRIMARY KEY NOT NULL,
        hidden_at INTEGER NOT NULL
      )
    ''');
  }
}
