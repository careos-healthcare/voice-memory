import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Lets a moment stay in the archive while leaving On This Day.
class Migration020OnThisDaySilence implements SqliteMigration {
  @override
  int get version => 20;

  @override
  String get id => '020_on_this_day_silence';

  static const column = 'is_silenced_from_on_this_day';

  @override
  Future<void> up(DatabaseExecutor db) async {
    final info = await db.rawQuery('PRAGMA table_info(journal_entries)');
    final exists = info.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute(
      'ALTER TABLE journal_entries ADD COLUMN $column INTEGER NOT NULL DEFAULT 0',
    );
  }
}
