import 'package:archiveme_mobile/models/time_capsule_lock.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_015_vec_chunks.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_019_time_capsules_and_daily_checkins.dart';
import 'package:sqflite/sqflite.dart';

/// Keeps locked time capsules out of embeddings and retrieval.
abstract final class TimeCapsuleVisibility {
  TimeCapsuleVisibility._();

  static const _columns = '''
    is_time_capsule, unlock_date, unlock_milestone_entry_count
  ''';

  /// SQL `AND` clause for alias [alias], or empty when the columns are absent.
  static Future<TimeCapsuleSearchWindow?> searchWindow(
    DatabaseExecutor db, {
    DateTime? now,
  }) async {
    if (!await _hasTimeCapsuleColumn(db)) return null;
    final countRows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable}
      WHERE deleted_at IS NULL
      ''',
    );
    final count = countRows.first['count'] as int? ?? 0;
    return TimeCapsuleSearchWindow(
      nowMillis: (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch,
      activeEntryCount: count,
    );
  }

  /// True when [entryId] is a capsule whose date and milestone are still closed.
  static Future<bool> isEntryLocked(
    DatabaseExecutor db,
    String entryId, {
    DateTime? now,
  }) async {
    if (entryId.isEmpty || !await _hasTimeCapsuleColumn(db)) return false;
    final rows = await db.rawQuery(
      '''
      SELECT $_columns
      FROM ${Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable}
      WHERE id = ?
      ''',
      [entryId],
    );
    if (rows.isEmpty) return false;
    final window = await searchWindow(db, now: now);
    if (window == null) return false;
    return !TimeCapsuleLock.fromRow(rows.first).isUnlocked(
      nowMillis: window.nowMillis,
      activeEntryCount: window.activeEntryCount,
    );
  }

  static Future<Set<String>> lockedEntryIds(
    DatabaseExecutor db, {
    DateTime? now,
  }) async {
    final window = await searchWindow(db, now: now);
    if (window == null) return const {};
    final rows = await db.rawQuery(
      '''
      SELECT id
      FROM ${Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable}
      WHERE is_time_capsule = 1
        AND NOT (
          (unlock_date IS NOT NULL AND unlock_date <= ?)
          OR (
            unlock_milestone_entry_count IS NOT NULL
            AND unlock_milestone_entry_count <= ?
          )
        )
      ''',
      [window.nowMillis, window.activeEntryCount],
    );
    return rows
        .map((row) => row['id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  static Future<List<T>> withoutLocked<T>(
    DatabaseExecutor db,
    List<T> hits,
    String Function(T hit) entryIdOf,
  ) async {
    if (hits.isEmpty) return hits;
    final locked = await lockedEntryIds(db);
    if (locked.isEmpty) return hits;
    return hits
        .where((hit) => !locked.contains(entryIdOf(hit)))
        .toList(growable: false);
  }

  /// Drops stored vectors for a capsule that is still locked.
  static Future<void> purgeEmbeddings(
    DatabaseExecutor db,
    String entryId,
  ) async {
    if (entryId.isEmpty) return;
    const tables = [
      Migration005HybridSearch.embeddingsTable,
      Migration005HybridSearch.vecTable,
      Migration015VecChunks.vecChunksTable,
      Migration009ReflectionEmbeddings.embeddingsTable,
      Migration009ReflectionEmbeddings.vecTable,
    ];
    for (final table in tables) {
      try {
        await db.delete(table, where: 'entry_id = ?', whereArgs: [entryId]);
      } on Object {
        // Optional vec0 tables are absent when the extension is not loaded.
      }
    }
  }

  static Future<bool> _hasTimeCapsuleColumn(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'PRAGMA table_info(${Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable})',
    );
    return rows.any(
      (row) =>
          row['name'] ==
          Migration019TimeCapsulesAndDailyCheckins.isTimeCapsuleColumn,
    );
  }
}

/// Bound parameters for the unlocked-capsule predicate.
final class TimeCapsuleSearchWindow {
  const TimeCapsuleSearchWindow({
    required this.nowMillis,
    required this.activeEntryCount,
  });

  final int nowMillis;
  final int activeEntryCount;

  String andSql(String alias) =>
      '''
    AND (
      $alias.is_time_capsule = 0
      OR ($alias.unlock_date IS NOT NULL AND $alias.unlock_date <= ?)
      OR (
        $alias.unlock_milestone_entry_count IS NOT NULL
        AND $alias.unlock_milestone_entry_count <= ?
      )
    )
  ''';

  List<Object> get args => [nowMillis, activeEntryCount];
}
