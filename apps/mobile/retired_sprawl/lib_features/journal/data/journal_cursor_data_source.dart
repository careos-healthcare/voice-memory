import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/features/journal/domain/task_node.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Fetches serializable SQLite row maps for background entity parsing.
///
/// Queries use keyset cursors (`created_at` / `updated_at` + `id`) rather than
/// OFFSET so memory and latency stay flat as tables grow.
final class JournalCursorDataSource {
  JournalCursorDataSource(this._sqlite);

  static const journalTable = DatabaseConstants.journalEntriesTable;
  static const pageSize = DatabaseConstants.defaultPageSize;

  final AppSqliteDatabase _sqlite;
  AppDatabase? _drift;
  JournalDao? _journalDao;
  ReflectionGraphDao? _graphDao;

  AppDatabase get _driftDb =>
      _drift ??= AppDatabase.fromSqflite(_sqlite.database);

  JournalDao get _journal =>
      _journalDao ??= JournalDao(_driftDb);

  ReflectionGraphDao get _graph =>
      _graphDao ??= ReflectionGraphDao(_driftDb);

  Future<List<Map<String, dynamic>>> fetchJournalEntryRows({
    JournalFeedCursor? after,
    int limit = pageSize,
  }) {
    return _journal.fetchJournalEntryRows(
      afterCreatedAt: after?.createdAt,
      afterId: after?.id,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> fetchTaskNodeRows({
    TaskNodeFeedCursor? after,
    int limit = pageSize,
  }) {
    return _graph.fetchTaskNodeRows(
      afterUpdatedAt: after?.updatedAt,
      afterId: after?.id,
      limit: limit,
    );
  }
}

Map<String, dynamic> _toDynamicMap(Map<String, Object?> row) =>
    row.map((key, value) => MapEntry(key, value));
