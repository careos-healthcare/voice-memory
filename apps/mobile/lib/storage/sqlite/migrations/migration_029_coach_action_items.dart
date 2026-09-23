import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Action items and shareable clips kept inside the encrypted database.
///
/// New tables are created in place. [clipIdColumn] is added afterwards so an
/// install that already created [table] keeps its cr-sqlite bookkeeping.
/// The added column is nullable so a delayed mesh delta can omit it.
class Migration029CoachActionItems implements SqliteMigration {
  @override
  int get version => 29;

  @override
  String get id => '029_coach_action_items';

  static const table = 'coach_action_items';
  static const clipsTable = 'clips';
  static const clipIdColumn = 'clip_id';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        text TEXT NOT NULL,
        timeline_label TEXT NOT NULL,
        estimate_minutes INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final columns = <String>{
      for (final row in info) '${row['name']}',
    };
    if (!columns.contains(clipIdColumn)) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $clipIdColumn TEXT',
      );
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $clipsTable (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        start_offset INTEGER NOT NULL DEFAULT 0,
        end_offset INTEGER NOT NULL DEFAULT 0,
        text TEXT NOT NULL DEFAULT '',
        tags TEXT
      )
    ''');
  }
}
