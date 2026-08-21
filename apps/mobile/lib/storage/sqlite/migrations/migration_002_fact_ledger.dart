import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite mirror of user citable facts for fast counts and queries.
class Migration002FactLedger implements SqliteMigration {
  @override
  int get version => 2;

  @override
  String get id => '002_fact_ledger';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fact_ledger (
        id TEXT PRIMARY KEY NOT NULL,
        source_entry_id TEXT NOT NULL,
        label TEXT NOT NULL,
        value TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        fact_type TEXT NOT NULL,
        archive_pack_id TEXT,
        archive_thread_id TEXT,
        collection_ids_json TEXT NOT NULL DEFAULT '[]',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        preserve_original INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fact_ledger_source_entry
      ON fact_ledger(source_entry_id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_fact_ledger_updated_at
      ON fact_ledger(updated_at DESC)
    ''');
  }
}