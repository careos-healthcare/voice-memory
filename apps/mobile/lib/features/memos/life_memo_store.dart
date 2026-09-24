import 'dart:convert';

import 'package:archiveme_mobile/features/memos/life_memo_generator.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes the `life_memos` table.
abstract final class LifeMemoStore {
  static const table = 'life_memos';

  static Future<void> save(DatabaseExecutor db, LifeMemo memo) async {
    await db.insert(table, {
      'id': memo.id,
      'period': memo.period.name,
      'window_start': memo.windowStart.millisecondsSinceEpoch,
      'window_end': memo.windowEnd.millisecondsSinceEpoch,
      'title': memo.title,
      'markdown': memo.markdown,
      'evidence_entry_ids': jsonEncode(memo.evidenceEntryIds),
      'created_at': memo.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<List<LifeMemo>> list(DatabaseExecutor db) async {
    try {
      final rows = await db.query(table, orderBy: 'window_end DESC, id ASC');
      return rows.map(_memo).toList(growable: false);
    } on Object {
      return const [];
    }
  }

  static Future<List<MemoSourceEntry>> entriesIn(
    DatabaseExecutor db, {
    required DateTime start,
    required DateTime end,
  }) async {
    final rows = await db.rawQuery(
      '''
      SELECT id, created_at, transcript
      FROM journal_entries
      WHERE deleted_at IS NULL
        AND created_at >= ?
        AND created_at <= ?
      ORDER BY created_at ASC, id ASC
      ''',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    return [
      for (final row in rows)
        MemoSourceEntry(
          id: row['id'] as String? ?? '',
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int? ?? 0,
          ),
          transcript: row['transcript'] as String? ?? '',
        ),
    ];
  }

  static Future<List<MemoSourceEntity>> entitiesIn(
    DatabaseExecutor db, {
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final rows = await db.rawQuery(
        '''
        SELECT name, category, created_at
        FROM entities
        WHERE created_at >= ? AND created_at <= ?
        ORDER BY created_at ASC, id ASC
        ''',
        [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      );
      return [
        for (final row in rows)
          MemoSourceEntity(
            name: row['name'] as String? ?? '',
            category: row['category'] as String? ?? '',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              row['created_at'] as int? ?? 0,
            ),
          ),
      ];
    } on Object {
      return const [];
    }
  }

  static LifeMemo _memo(Map<String, Object?> row) {
    final periodName = row['period'] as String? ?? LifeMemoPeriod.weekly.name;
    final period = LifeMemoPeriod.values.firstWhere(
      (item) => item.name == periodName,
      orElse: () => LifeMemoPeriod.weekly,
    );
    final rawIds = row['evidence_entry_ids'] as String? ?? '[]';
    final decoded = jsonDecode(rawIds);
    final ids = decoded is List
        ? [for (final id in decoded) '$id']
        : const <String>[];
    return LifeMemo(
      id: row['id'] as String? ?? '',
      period: period,
      windowStart: DateTime.fromMillisecondsSinceEpoch(
        row['window_start'] as int? ?? 0,
      ),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(
        row['window_end'] as int? ?? 0,
      ),
      title: row['title'] as String? ?? '',
      markdown: row['markdown'] as String? ?? '',
      evidenceEntryIds: ids,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
    );
  }
}
