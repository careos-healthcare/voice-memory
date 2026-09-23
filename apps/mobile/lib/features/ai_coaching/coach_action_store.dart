import 'package:archiveme_mobile/features/ai_coaching/coach_action_plan.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_029_coach_action_items.dart';
import 'package:sqflite/sqflite.dart';

/// Writes coach action items into the encrypted local database.
class CoachActionStore {
  CoachActionStore(this._db);

  final DatabaseExecutor _db;

  static const table = Migration029CoachActionItems.table;

  Future<void> ensureTable() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        text TEXT NOT NULL,
        timeline_label TEXT NOT NULL,
        estimate_minutes INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> replaceForEntry({
    required String entryId,
    required List<CoachActionItem> items,
  }) async {
    await Future<void>.delayed(Duration.zero);
    await ensureTable();
    await _db.delete(table, where: 'entry_id = ?', whereArgs: [entryId]);
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      await _db.insert(table, {
        'id': '$entryId:$index',
        'entry_id': entryId,
        'text': item.text,
        'timeline_label': item.timelineLabel,
        'estimate_minutes': item.estimateMinutes,
        'created_at': now,
      });
    }
  }

  Future<List<CoachActionItem>> read(String entryId) async {
    await ensureTable();
    final rows = await _db.query(
      table,
      where: 'entry_id = ?',
      whereArgs: [entryId],
      orderBy: 'id ASC',
    );
    return [
      for (final row in rows)
        CoachActionItem(
          text: row['text']! as String,
          timelineLabel: row['timeline_label']! as String,
          estimateMinutes: (row['estimate_minutes'] as num).toInt(),
        ),
    ];
  }
}
