import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Adds the JSON surroundings column on journal entries.
class Migration021AmbientMetadata implements SqliteMigration {
  @override
  int get version => 21;

  @override
  String get id => '021_ambient_metadata';

  static const journalEntriesTable = 'journal_entries';
  static const column = 'ambient_metadata';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'PRAGMA table_info($journalEntriesTable)',
    );
    final exists = rows.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute(
      'ALTER TABLE $journalEntriesTable ADD COLUMN $column TEXT',
    );
  }
}
