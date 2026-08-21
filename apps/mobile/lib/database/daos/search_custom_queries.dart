import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/database/app_database.dart';
import 'package:archiveme_mobile/database/daos/journal_dao.dart';
import 'package:drift/drift.dart';

/// FTS5 / hybrid search queries that cannot be expressed with typed Drift selects.
class SearchCustomQueries {
  SearchCustomQueries(this._db);

  final AppDatabase _db;

  Future<List<Map<String, Object?>>> fetchFtsPageAfter({
    required String ftsMatchQuery,
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    final keyset = _keysetSql(
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
      tableAlias: 'je',
    );
    final rows = await _db.customSelect(
      '''
      SELECT
        je.id,
        je.created_at,
        je.updated_at,
        je.deleted_at,
        je.is_archived,
        je.transcript,
        je.has_verified_proof,
        je.payload_json
      FROM ${DatabaseConstants.journalEntriesTable} je
      INNER JOIN (
        SELECT entry_id, MIN(rank) AS best_rank
        FROM (
          SELECT entry_id, bm25(${DatabaseConstants.ftsTable}) AS rank
          FROM ${DatabaseConstants.ftsTable}
          WHERE transcript MATCH ?
          UNION ALL
          SELECT entry_id, bm25(${DatabaseConstants.graphNodeFtsTable}) AS rank
          FROM ${DatabaseConstants.graphNodeFtsTable}
          WHERE ${DatabaseConstants.graphNodeFtsTable} MATCH ?
        )
        GROUP BY entry_id
      ) ranked ON ranked.entry_id = je.id
      WHERE je.deleted_at IS NULL
        ${keyset.clause}
      ORDER BY ranked.best_rank ASC, je.created_at DESC, je.id DESC
      LIMIT ?
      ''',
      variables: [
        Variable<String>(ftsMatchQuery),
        Variable<String>(ftsMatchQuery),
        ...keyset.variables,
        Variable<int>(limit),
      ],
      readsFrom: {_db.journalEntries},
    ).get();

    return rows.map((row) => row.data).toList();
  }

  Future<int> countActiveFts({required String ftsMatchQuery}) async {
    final row = await _db.customSelect(
      '''
      SELECT COUNT(DISTINCT je.id) AS count
      FROM ${DatabaseConstants.journalEntriesTable} je
      WHERE je.deleted_at IS NULL
        AND je.id IN (
          SELECT entry_id FROM ${DatabaseConstants.ftsTable}
          WHERE transcript MATCH ?
          UNION
          SELECT entry_id FROM ${DatabaseConstants.graphNodeFtsTable}
          WHERE ${DatabaseConstants.graphNodeFtsTable} MATCH ?
        )
      ''',
      variables: [
        Variable<String>(ftsMatchQuery),
        Variable<String>(ftsMatchQuery),
      ],
      readsFrom: {_db.journalEntries},
    ).getSingle();
    return row.read<int>('count');
  }

  ({String clause, List<Variable<Object>> variables}) _keysetSql({
    required DateTime? afterCreatedAt,
    required String? afterId,
    required String tableAlias,
  }) {
    if (afterCreatedAt == null || afterId == null) {
      return (clause: '', variables: []);
    }

    final prefix = tableAlias.isEmpty ? '' : '$tableAlias.';
    final createdAtMillis = afterCreatedAt.toUtc().millisecondsSinceEpoch;
    return (
      clause: '''
        AND (
          ${prefix}created_at < ?
          OR (${prefix}created_at = ? AND ${prefix}id < ?)
        )
      ''',
      variables: [
        Variable<int>(createdAtMillis),
        Variable<int>(createdAtMillis),
        Variable<String>(afterId),
      ],
    );
  }
}

/// Backward-compatible wrapper for legacy call sites.
class JournalKeysetQueries {
  JournalKeysetQueries(AppDatabase db)
      : _dao = JournalDao(db),
        _search = SearchCustomQueries(db);

  final JournalDao _dao;
  final SearchCustomQueries _search;

  Future<List<Map<String, Object?>>> fetchActivePageAfter({
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
  }) =>
      _dao.fetchActivePageAfter(
        limit: limit,
        afterCreatedAt: afterCreatedAt,
        afterId: afterId,
      );

  Future<List<Map<String, Object?>>> fetchFtsPageAfter({
    required String ftsMatchQuery,
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
  }) =>
      _search.fetchFtsPageAfter(
        ftsMatchQuery: ftsMatchQuery,
        limit: limit,
        afterCreatedAt: afterCreatedAt,
        afterId: afterId,
      );

  Future<int> countActiveFts({required String ftsMatchQuery}) =>
      _search.countActiveFts(ftsMatchQuery: ftsMatchQuery);
}
