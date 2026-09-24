import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Stores on-device text from photo and document attachments.
class Migration023AttachmentText implements SqliteMigration {
  @override
  int get version => 23;

  @override
  String get id => '023_attachment_text';

  static const journalEntriesTable = 'journal_entries';
  static const column = 'attachment_text';
  static const attachmentsTable = 'entry_attachments';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final rows = await db.rawQuery('PRAGMA table_info($journalEntriesTable)');
    final exists = rows.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $journalEntriesTable ADD COLUMN $column TEXT',
      );
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $attachmentsTable (
        id TEXT PRIMARY KEY NOT NULL,
        entry_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        attachment_text TEXT NOT NULL DEFAULT '',
        embedding BLOB,
        FOREIGN KEY (entry_id) REFERENCES $journalEntriesTable(id)
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_attachments_entry
      ON $attachmentsTable(entry_id)
    ''');
  }
}
