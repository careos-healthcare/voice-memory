import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/storage/drift/sqflite_executor.dart';
import 'package:archiveme_mobile/storage/drift/tables/journal_entries.dart';
import 'package:drift/drift.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

part 'journal_database.g.dart';

/// Drift access layer for journal SQLite tables managed by sqflite migrations.
///
/// Schema creation remains in [SqliteMigrationRunner]; this database is opened
/// read/write against the existing handle for typed queries only.
@DriftDatabase(tables: [JournalEntries])
class JournalDatabase extends _$JournalDatabase {
  JournalDatabase(sqflite.Database db) : super(WrappedSqfliteExecutor(db));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {},
    onUpgrade: (m, from, to) async {},
  );
}

/// Typed keyset pagination and FTS query compilation for [JournalSqliteRepository].
class JournalKeysetQueries {
  JournalKeysetQueries(this._db);

  final JournalDatabase _db;

  static const journalSelectColumns = '''
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      ''';

  /// Active feed page after cursor — replaces raw `_keysetSeekClause` strings.
  Future<List<Map<String, Object?>>> fetchActivePageAfter({
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
  }) async {
    final query = _db.select(_db.journalEntries)
      ..where((t) => t.deletedAt.isNull())
      ..where(_keysetCondition(afterCreatedAt: afterCreatedAt, afterId: afterId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.createdAt),
        (t) => OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_journalRowToSqlMap).toList();
  }

  /// FTS-backed search page with typed keyset seek on journal columns.
  ///
  /// FTS5 virtual tables remain custom SQL — see [fetchFtsPageAfter].
  Future<List<Map<String, Object?>>> fetchFtsPageAfter({
    required String searchQuery,
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
      INNER JOIN ${DatabaseConstants.ftsTable} fts ON fts.entry_id = je.id
      WHERE je.deleted_at IS NULL
        AND fts.transcript MATCH ?
        ${keyset.clause}
      ORDER BY bm25(${DatabaseConstants.ftsTable}) ASC, je.created_at DESC, je.id DESC
      LIMIT ?
      ''',
      variables: [
        Variable<String>(searchQuery),
        ...keyset.variables,
        Variable<int>(limit),
      ],
      readsFrom: {_db.journalEntries},
    ).get();

    return rows.map((row) => row.data).toList();
  }

  Expression<bool> Function(JournalEntries tbl) _keysetCondition({
    required DateTime? afterCreatedAt,
    required String? afterId,
  }) {
    if (afterCreatedAt == null || afterId == null) {
      return (_) => const Constant(true);
    }

    final createdAtMillis = afterCreatedAt.toUtc().millisecondsSinceEpoch;
    return (t) =>
        t.createdAt.isSmallerThanValue(createdAtMillis) |
        (t.createdAt.equals(createdAtMillis) &
            t.id.isSmallerThanValue(afterId));
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

  Map<String, Object?> _journalRowToSqlMap(JournalEntryRow row) => {
    'id': row.id,
    'created_at': row.createdAt,
    'updated_at': row.updatedAt,
    'deleted_at': row.deletedAt,
    'is_archived': row.isArchived,
    'transcript': row.transcript,
    'has_verified_proof': row.hasVerifiedProof,
    'payload_json': row.payloadJson,
  };
}
