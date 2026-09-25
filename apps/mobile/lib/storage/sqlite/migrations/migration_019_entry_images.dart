import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Stores a JSON list of local image paths or URLs beside each journal row.
class Migration019EntryImages implements SqliteMigration {
  @override
  int get version => 19;

  @override
  String get id => '019_entry_images';

  static const column = 'images_json';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final info = await db.rawQuery('PRAGMA table_info(journal_entries)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute(
      "ALTER TABLE journal_entries ADD COLUMN $column TEXT NOT NULL DEFAULT '[]'",
    );
  }
}
