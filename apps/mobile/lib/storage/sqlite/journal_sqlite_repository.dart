import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_log.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sqflite/sqflite.dart';

/// Corruption detected while decoding a journal SQLite row.
class JournalRowCorruption {
  const JournalRowCorruption({
    required this.entryId,
    required this.error,
  });

  final String entryId;
  final Object error;
}

/// SQLite-backed journal queries for paginated Archive Home scrolling.
class JournalSqliteRepository {
  JournalSqliteRepository(this._sqlite);

  static const table = DatabaseConstants.journalEntriesTable;
  static const defaultPageSize = DatabaseConstants.defaultPageSize;

  final AppSqliteDatabase _sqlite;
  MemoryTranscriptSearchRepository? _searchRepository;

  MemoryTranscriptSearchRepository get _transcriptSearch =>
      _searchRepository ??= MemoryTranscriptSearchRepository(_sqlite);

  /// Upserts a local transcript embedding for hybrid search (384-d).
  Future<void> upsertTranscriptEmbedding({
    required String entryId,
    required List<double> embedding,
  }) => _transcriptSearch.upsertEmbedding(
    entryId: entryId,
    embedding: embedding,
  );

  /// Deletes the transcript embedding row for [entryId].
  Future<void> deleteTranscriptEmbedding(String entryId) =>
      _transcriptSearch.deleteEmbedding(entryId);

  /// BM25 + vector hybrid search over local transcript embeddings.
  Future<List<String>> vectorSearchTranscripts({
    required List<double> queryEmbedding,
    int limit = 20,
  }) => _transcriptSearch.vectorSearch(
    queryEmbedding: queryEmbedding,
    limit: limit,
  );

  /// Upserts [entries] without deleting rows absent from the batch.
  Future<void> upsertEntries(List<JournalEntry> entries) async {
    if (entries.isEmpty) return;

    final db = _sqlite.database;
    final ids = entries.map((entry) => entry.id).toSet();

    await db.transaction((txn) async {
      final existingById = await _loadExistingSyncState(txn, ids);

      for (final entry in entries) {
        await _upsertJournalRow(txn, entry);
        await _syncFtsRow(
          txn,
          entry: entry,
          existing: existingById[entry.id],
        );
      }
    });
  }

  /// Replaces the local mirror with [entries], deleting any row not in the batch.
  ///
  /// **Callers MUST pass the complete authoritative entry set** for the mirror.
  /// Partial lists will delete every other locally mirrored row.
  ///
  /// This method always mirrors the full authoritative set — there is no partial
  /// mode. Use [upsertEntries] for incremental updates.
  Future<void> mirrorEntireRemoteState(List<JournalEntry> entries) async {
    final db = _sqlite.database;
    final ids = entries.map((entry) => entry.id).toSet();

    await db.transaction((txn) async {
      if (ids.isEmpty) {
        await txn.delete(table);
        await txn.delete(DatabaseConstants.ftsTable);
        await txn.delete(DatabaseConstants.transcriptEmbeddingsTable);
        await txn.delete(DatabaseConstants.imageEmbeddingsTable);
        return;
      }

      final existingById = await _loadExistingSyncState(txn, ids);

      for (final entry in entries) {
        await _upsertJournalRow(txn, entry);
        await _syncFtsRow(
          txn,
          entry: entry,
          existing: existingById[entry.id],
        );
      }

      await _deleteAbsentRows(txn, ids);
    });
  }

  @Deprecated('Use upsertEntries or mirrorEntireRemoteState instead.')
  Future<void> syncFromEntries(List<JournalEntry> entries) =>
      mirrorEntireRemoteState(entries);

  Future<JournalEntry?> findByCaptureContextTag(String tag) async {
    try {
      final rows = await _sqlite.database.rawQuery(
        '''
        SELECT
          id,
          created_at,
          updated_at,
          deleted_at,
          is_archived,
          transcript,
          has_verified_proof,
          payload_json
        FROM $table
        WHERE deleted_at IS NULL
          AND json_extract(payload_json, '${DatabaseConstants.captureContextTagJsonPath}') = ?
        LIMIT 1
        ''',
        [tag],
      );
      if (rows.isEmpty) return null;
      return _entryFromRow(rows.single).fold(
        (corruption) {
          JournalSqliteLog.corruptPayloadJson(entryId: corruption.entryId);
          return null;
        },
        (entry) => entry,
      );
    } on Object {
      JournalSqliteLog.corruptPayloadJson(entryId: tag);
      return null;
    }
  }

  Future<Map<String, _ExistingJournalSyncState>> _loadExistingSyncState(
    Transaction txn,
    Set<String> ids,
  ) async {
    if (ids.isEmpty) return const {};

    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await txn.rawQuery(
      '''
      SELECT id, transcript, deleted_at
      FROM $table
      WHERE id IN ($placeholders)
      ''',
      ids.toList(growable: false),
    );

    return {
      for (final row in rows)
        row['id'] as String: _ExistingJournalSyncState(
          transcript: row['transcript'] as String? ?? '',
          deletedAt: row['deleted_at'] as int?,
        ),
    };
  }

  Future<void> _upsertJournalRow(Transaction txn, JournalEntry entry) async {
    final row = _rowFor(entry);
    await txn.rawInsert(
      '''
      INSERT INTO $table (
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at,
        is_archived = excluded.is_archived,
        transcript = excluded.transcript,
        has_verified_proof = excluded.has_verified_proof,
        payload_json = excluded.payload_json
      ''',
      [
        row['id'],
        row['created_at'],
        row['updated_at'],
        row['deleted_at'],
        row['is_archived'],
        row['transcript'],
        row['has_verified_proof'],
        row['payload_json'],
      ],
    );
  }

  Future<void> _syncFtsRow(
    Transaction txn, {
    required JournalEntry entry,
    required _ExistingJournalSyncState? existing,
  }) async {
    final entryId = entry.id;
    final isDeleted = entry.deletedAt != null;
    final wasDeleted = existing?.deletedAt != null;
    final transcriptChanged =
        existing == null || existing.transcript != entry.transcript;

    if (isDeleted) {
      if (!wasDeleted) {
        await _deleteFtsRow(txn, entryId);
      }
      return;
    }

    if (!transcriptChanged) {
      return;
    }

    await _deleteFtsRow(txn, entryId);
    await txn.insert(DatabaseConstants.ftsTable, {
      'entry_id': entryId,
      'transcript': entry.transcript,
    });
  }

  Future<void> _deleteFtsRow(Transaction txn, String entryId) async {
    await txn.rawDelete(
      'DELETE FROM ${DatabaseConstants.ftsTable} WHERE entry_id = ?',
      [entryId],
    );
  }

  Future<void> _deleteAbsentRows(Transaction txn, Set<String> ids) async {
    await _deleteWhereIdNotIn(
      txn,
      table: table,
      ids: ids,
    );
    await _deleteWhereIdNotIn(
      txn,
      table: DatabaseConstants.ftsTable,
      ids: ids,
      idColumn: 'entry_id',
    );
    await _deleteWhereIdNotIn(
      txn,
      table: DatabaseConstants.transcriptEmbeddingsTable,
      ids: ids,
      idColumn: 'entry_id',
    );
    await _deleteWhereIdNotIn(
      txn,
      table: DatabaseConstants.imageEmbeddingsTable,
      ids: ids,
      idColumn: 'entry_id',
    );
  }

  Future<void> _deleteWhereIdNotIn(
    Transaction txn, {
    required String table,
    required Set<String> ids,
    String idColumn = 'id',
  }) async {
    final keepIds = ids.toList(growable: false);
    if (keepIds.isEmpty) {
      await txn.delete(table);
      return;
    }

    final existingRows = await txn.rawQuery(
      'SELECT DISTINCT $idColumn AS row_id FROM $table',
    );
    final toDelete = <String>[];
    for (final row in existingRows) {
      final rowId = row['row_id'] as String?;
      if (rowId == null || keepIds.contains(rowId)) continue;
      toDelete.add(rowId);
    }

    if (toDelete.isEmpty) return;

    for (
      var offset = 0;
      offset < toDelete.length;
      offset += DatabaseConstants.deleteNotInChunkSize
    ) {
      final end = offset + DatabaseConstants.deleteNotInChunkSize > toDelete.length
          ? toDelete.length
          : offset + DatabaseConstants.deleteNotInChunkSize;
      final chunk = toDelete.sublist(offset, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      await txn.rawDelete(
        'DELETE FROM $table WHERE $idColumn IN ($placeholders)',
        chunk,
      );
    }
  }

  /// All non-deleted journal rows — for local bulk export.
  Future<List<JournalEntry>> fetchAllActive() async {
    final rows = await _sqlite.database.rawQuery(
      '''
      SELECT
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      FROM $table
      WHERE deleted_at IS NULL
      ORDER BY created_at ASC, id ASC
      ''',
    );
    return _entriesFromRows(rows);
  }

  Future<int> countActive({String? searchQuery}) async {
    final trimmedQuery = searchQuery?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      try {
        final rows = await _sqlite.database.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM $table je
          INNER JOIN ${DatabaseConstants.ftsTable} fts ON fts.entry_id = je.id
          WHERE je.deleted_at IS NULL
            AND fts.transcript MATCH ?
          ''',
          [trimmedQuery],
        );
        return (rows.first['count'] as int?) ?? 0;
      } on Object catch (error) {
        JournalSqliteLog.fetchPageFtsFallback(error: error);
      }
    }

    final whereClause = _activeWhereClause(searchQuery);
    final rows = await _sqlite.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $table WHERE $whereClause',
      _whereArgs(searchQuery),
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  @Deprecated('Use fetchPageAfter for keyset pagination.')
  Future<List<JournalEntry>> fetchPage({
    required int offset,
    int limit = defaultPageSize,
    String? searchQuery,
  }) async {
    final trimmedQuery = searchQuery?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      try {
        final rows = await _sqlite.database.rawQuery(
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
          FROM $table je
          INNER JOIN ${DatabaseConstants.ftsTable} fts ON fts.entry_id = je.id
          WHERE je.deleted_at IS NULL
            AND fts.transcript MATCH ?
          ORDER BY bm25(${DatabaseConstants.ftsTable}) ASC, je.created_at DESC, je.id DESC
          LIMIT ? OFFSET ?
          ''',
          [trimmedQuery, limit, offset],
        );
        return _entriesFromRows(rows);
      } on Object catch (error) {
        JournalSqliteLog.fetchPageFtsFallback(error: error);
      }
    }

    final whereClause = _activeWhereClause(searchQuery);
    final rows = await _sqlite.database.rawQuery(
      '''
      SELECT
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      FROM $table
      WHERE $whereClause
      ORDER BY created_at DESC, id DESC
      LIMIT ? OFFSET ?
      ''',
      [..._whereArgs(searchQuery), limit, offset],
    );
    return _entriesFromRows(rows);
  }

  Future<List<JournalEntry>> fetchPageAfter({
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
    String? searchQuery,
  }) async {
    final trimmedQuery = searchQuery?.trim();
    if (trimmedQuery != null && trimmedQuery.isNotEmpty) {
      try {
        return _fetchSearchPageAfterFts(
          limit: limit,
          afterCreatedAt: afterCreatedAt,
          afterId: afterId,
          searchQuery: trimmedQuery,
        );
      } on Object catch (error) {
        JournalSqliteLog.fetchPageFtsFallback(error: error);
      }
    }

    final args = <Object?>[];
    final seekClause = _keysetSeekClause(
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
      args: args,
    );
    final rows = await _sqlite.database.rawQuery(
      '''
      SELECT
        id,
        created_at,
        updated_at,
        deleted_at,
        is_archived,
        transcript,
        has_verified_proof,
        payload_json
      FROM $table
      WHERE deleted_at IS NULL
        $seekClause
      ORDER BY created_at DESC, id DESC
      LIMIT ?
      ''',
      [...args, limit],
    );
    return _entriesFromRows(rows);
  }

  Future<List<JournalEntry>> _fetchSearchPageAfterFts({
    required int limit,
    DateTime? afterCreatedAt,
    String? afterId,
    required String searchQuery,
  }) async {
    final args = <Object?>[searchQuery];
    final seekClause = _keysetSeekClause(
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
      args: args,
      tableAlias: 'je',
    );
    final rows = await _sqlite.database.rawQuery(
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
      FROM $table je
      INNER JOIN ${DatabaseConstants.ftsTable} fts ON fts.entry_id = je.id
      WHERE je.deleted_at IS NULL
        AND fts.transcript MATCH ?
        $seekClause
      ORDER BY bm25(${DatabaseConstants.ftsTable}) ASC, je.created_at DESC, je.id DESC
      LIMIT ?
      ''',
      [...args, limit],
    );
    return _entriesFromRows(rows);
  }

  String _keysetSeekClause({
    required DateTime? afterCreatedAt,
    required String? afterId,
    required List<Object?> args,
    String tableAlias = '',
  }) {
    if (afterCreatedAt == null || afterId == null) {
      return '';
    }

    final prefix = tableAlias.isEmpty ? '' : '$tableAlias.';
    final createdAtMillis = afterCreatedAt.toUtc().millisecondsSinceEpoch;
    args
      ..add(createdAtMillis)
      ..add(createdAtMillis)
      ..add(afterId);
    return '''
      AND (
        ${prefix}created_at < ?
        OR (${prefix}created_at = ? AND ${prefix}id < ?)
      )
    ''';
  }

  Future<List<JournalEntry>> fetchProofContextStubs() async {
    final rows = await _sqlite.database.query(
      table,
      columns: ['id', 'created_at', 'transcript', 'is_archived'],
      where: 'deleted_at IS NULL',
    );
    return rows.map(_proofStubFromRow).toList();
  }

  Future<List<JournalEntry>> fetchVerifiedProofEntries() async {
    final rows = await _sqlite.database.query(
      table,
      columns: [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        'is_archived',
        'transcript',
        'has_verified_proof',
        'payload_json',
      ],
      where: 'deleted_at IS NULL AND has_verified_proof = 1',
      orderBy: 'created_at DESC',
    );
    return _entriesFromRows(rows);
  }

  String _activeWhereClause(String? searchQuery) {
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return 'deleted_at IS NULL';
    }
    return 'deleted_at IS NULL AND LOWER(transcript) LIKE ? ESCAPE \'\\\'';
  }

  List<Object?> _whereArgs(String? searchQuery) {
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return const [];
    }
    final escaped = searchQuery
        .trim()
        .toLowerCase()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    return ['%$escaped%'];
  }

  Map<String, Object?> _rowFor(JournalEntry entry) {
    return {
      'id': entry.id,
      'created_at': entry.createdAt.toUtc().millisecondsSinceEpoch,
      'updated_at': entry.updatedAt.toUtc().millisecondsSinceEpoch,
      'deleted_at': entry.deletedAt?.toUtc().millisecondsSinceEpoch,
      'is_archived': entry.isArchived ? 1 : 0,
      'transcript': entry.transcript,
      'has_verified_proof': entry.verifiedProof != null ? 1 : 0,
      'payload_json': _encodeResidualPayload(entry),
    };
  }

  String? _encodeResidualPayload(JournalEntry entry) {
    final payload = entry.toResidualJson();
    if (payload.isEmpty) {
      return null;
    }
    return jsonEncode(payload);
  }

  List<JournalEntry> _entriesFromRows(List<Map<String, Object?>> rows) {
    final entries = <JournalEntry>[];
    for (final row in rows) {
      _entryFromRow(row).fold(
        (corruption) =>
            JournalSqliteLog.corruptPayloadJson(entryId: corruption.entryId),
        entries.add,
      );
    }
    return entries;
  }

  Either<JournalRowCorruption, JournalEntry> _entryFromRow(
    Map<String, Object?> row,
  ) {
    final entryId = row['id'] as String? ?? '';
    final payloadJson = row['payload_json'] as String?;
    if (payloadJson == null || payloadJson.isEmpty) {
      return Right(_entryFromColumnsOnly(row));
    }

    try {
      final payload = Map<String, dynamic>.from(
        jsonDecode(payloadJson) as Map,
      );
      if (_isLegacyFullPayload(payload)) {
        return Right(JournalEntry.fromJson(payload));
      }

      return Right(
        JournalEntry.fromJson(_mergeColumnsIntoPayload(row, payload)),
      );
    } on Object catch (error) {
      return Left(
        JournalRowCorruption(
          entryId: entryId,
          error: error,
        ),
      );
    }
  }

  bool _isLegacyFullPayload(Map<String, dynamic> payload) {
    return payload.containsKey('id') && payload.containsKey('createdAt');
  }

  Map<String, dynamic> _mergeColumnsIntoPayload(
    Map<String, Object?> row,
    Map<String, dynamic> payload,
  ) {
    return {
      ...payload,
      'id': row['id'] as String? ?? '',
      'createdAt': _isoFromMillis(row['created_at'] as int?),
      'updatedAt': _isoFromMillis(row['updated_at'] as int?),
      'transcript': row['transcript'] as String? ?? '',
      'isArchived': (row['is_archived'] as int? ?? 0) == 1,
      if (row['deleted_at'] != null)
        'deletedAt': _isoFromMillis(row['deleted_at'] as int),
    };
  }

  JournalEntry _entryFromColumnsOnly(Map<String, Object?> row) {
    return JournalEntry.fromJson({
      'id': row['id'] as String? ?? '',
      'createdAt': _isoFromMillis(row['created_at'] as int?),
      'updatedAt': _isoFromMillis(row['updated_at'] as int?),
      'transcript': row['transcript'] as String? ?? '',
      'durationSeconds': 0,
      'reflection': const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ).toJson(),
      'isArchived': (row['is_archived'] as int? ?? 0) == 1,
      if (row['deleted_at'] != null)
        'deletedAt': _isoFromMillis(row['deleted_at'] as int),
    });
  }

  String _isoFromMillis(int? millis) {
    return DateTime.fromMillisecondsSinceEpoch(
      millis ?? 0,
      isUtc: true,
    ).toIso8601String();
  }

  JournalEntry _proofStubFromRow(Map<String, Object?> row) {
    return JournalEntry(
      id: row['id'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
        isUtc: true,
      ),
      transcript: row['transcript'] as String? ?? '',
      durationSeconds: 0,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      isArchived: (row['is_archived'] as int? ?? 0) == 1,
    );
  }
}

class _ExistingJournalSyncState {
  const _ExistingJournalSyncState({
    required this.transcript,
    required this.deletedAt,
  });

  final String transcript;
  final int? deletedAt;
}

/// Cursor for [JournalSqliteRepository.fetchPageAfter].
class JournalFeedCursor {
  const JournalFeedCursor({
    required this.createdAt,
    required this.id,
  });

  final DateTime createdAt;
  final String id;
}
