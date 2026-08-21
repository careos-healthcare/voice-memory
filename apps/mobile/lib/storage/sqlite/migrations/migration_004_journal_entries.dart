import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Paginated local mirror of journal entries for Archive Home feed queries.
class Migration004JournalEntries implements SqliteMigration {
  @override
  int get version => 4;

  @override
  String get id => '004_journal_entries';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entries (
        id TEXT PRIMARY KEY NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        is_archived INTEGER NOT NULL DEFAULT 0,
        transcript TEXT NOT NULL DEFAULT '',
        has_verified_proof INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_entries_active_created_at
      ON journal_entries(created_at DESC)
      WHERE deleted_at IS NULL
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_journal_entries_transcript
      ON journal_entries(transcript COLLATE NOCASE)
      WHERE deleted_at IS NULL
    ''');
  }
}