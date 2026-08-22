import 'dart:convert';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/sqlite/reflection_knowledge_graph_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_fts_query.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_bulk_sync.dart';
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
  ReflectionKnowledgeGraphRepository? _graphRepository;
  JournalDatabase? _driftDb;
  JournalKeysetQueries? _keysetQueries;

  JournalDatabase get _drift =>
      _driftDb ??= AppDatabase.fromSqflite(_sqlite.database);

  JournalKeysetQueries get _keyset =>
      _keysetQueries ??= JournalKeysetQueries(_drift);

  MemoryTranscriptSearchRepository get _transcriptSearch =>
      _searchRepository ??= MemoryTranscriptSearchRepository(_sqlite);

  ReflectionKnowledgeGraphRepository get _graphSearch =>
      _graphRepository ??= ReflectionKnowledgeGraphRepository(_sqlite.database);

  /// BM25-ranked knowledge-graph node search via FTS5.
  Future<List<ReflectionGraphSearchHit>> searchKnowledgeGraphNodes({
    required String query,
    int limit = 20,
  }) => _graphSearch.searchNodes(query: query, limit: limit);

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

    if (_shouldRunInBackgroundIsolate(entries.length)) {
      await LocalDatabaseWorkerService.instance.runJournalUpsert(
        filePath: _sqlite.filePath,
        encryptionPassword: _sqlite.encryptionPassword,
        keyAlias: _sqlite.keyAlias,
        entries: entries,
      );
      return;
    }

    await JournalSqliteBulkSync.upsertEntries(_sqlite.database, entries);
  }

  /// Replaces the local mirror with [entries], deleting any row not in the batch.
  ///
  /// **Callers MUST pass the complete authoritative entry set** for the mirror.
  /// Partial lists will delete every other locally mirrored row.
  ///
  /// This method always mirrors the full authoritative set — there is no partial
  /// mode. Use [upsertEntries] for incremental updates.
  Future<void> mirrorEntireRemoteState(List<JournalEntry> entries) async {
    if (_shouldRunInBackgroundIsolate(entries.length)) {
      await LocalDatabaseWorkerService.instance.runJournalMirror(
        filePath: _sqlite.filePath,
        encryptionPassword: _sqlite.encryptionPassword,
        keyAlias: _sqlite.keyAlias,
        entries: entries,
      );
      return;
    }

    await JournalSqliteBulkSync.mirrorEntireRemoteState(_sqlite.database, entries);
  }

  bool _shouldRunInBackgroundIsolate(int entryCount) {
    return LocalDatabaseWorkerService.shouldUseBackgroundWorker(
      filePath: _sqlite.filePath,
      entryCount: entryCount,
    );
  }

  @Deprecated('Use upsertEntries or mirrorEntireRemoteState instead.')
  Future<void> syncFromEntries(List<JournalEntry> entries) =>
      mirrorEntireRemoteState(entries);

  Future<JournalEntry?> findByCaptureContextTag(String tag) async {
    try {
      final row = await _drift.journalDao.findActiveRowByCaptureContextTag(tag);
      if (row == null) return null;
      return _entryFromRow(row).fold(
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

  /// All non-deleted journal rows — for local bulk export.
  Future<List<JournalEntry>> fetchAllActive() async {
    final rows = await _drift.journalDao.fetchAllActiveRows();
    return _entriesFromRows(rows);
  }

  Future<int> countActive({String? searchQuery}) async {
    final ftsQuery = _ftsMatchQuery(searchQuery);
    if (ftsQuery != null) {
      try {
        return await _keyset.countActiveFts(ftsMatchQuery: ftsQuery);
      } on Object catch (error, stackTrace) {
        JournalSqliteLog.fetchPageFtsFallback(error: error);
      }
    }

    return _drift.journalDao.countActive(likePattern: _likePattern(searchQuery));
  }

  @Deprecated('Use fetchPageAfter for keyset pagination.')
  Future<List<JournalEntry>> fetchPage({
    required int offset,
    int limit = defaultPageSize,
    String? searchQuery,
  }) async {
    final ftsQuery = _ftsMatchQuery(searchQuery);
    if (ftsQuery != null) {
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
          INNER JOIN (${_unifiedFtsRankSubquery()}) ranked
            ON ranked.entry_id = je.id
          WHERE je.deleted_at IS NULL
          ORDER BY ranked.best_rank ASC, je.created_at DESC, je.id DESC
          LIMIT ? OFFSET ?
          ''',
          [ftsQuery, ftsQuery, limit, offset],
        );
        return _entriesFromRows(rows);
      } on Object catch (error, stackTrace) {
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
    final ftsQuery = _ftsMatchQuery(searchQuery);
    if (ftsQuery != null) {
      try {
        final rows = await _keyset.fetchFtsPageAfter(
          ftsMatchQuery: ftsQuery,
          limit: limit,
          afterCreatedAt: afterCreatedAt,
          afterId: afterId,
        );
        return _entriesFromRows(rows);
      } on Object catch (error, stackTrace) {
        JournalSqliteLog.fetchPageFtsFallback(error: error);
      }
    }

    final rows = await _keyset.fetchActivePageAfter(
      limit: limit,
      afterCreatedAt: afterCreatedAt,
      afterId: afterId,
    );
    return _entriesFromRows(rows);
  }

  Future<List<JournalEntry>> fetchProofContextStubs() async {
    final rows = await _drift.journalDao.fetchProofContextStubRows();
    return rows.map(_proofStubFromRow).toList();
  }

  Future<List<JournalEntry>> fetchVerifiedProofEntries() async {
    final rows = await _drift.journalDao.fetchVerifiedProofRows();
    return _entriesFromRows(rows);
  }

  String? _likePattern(String? searchQuery) {
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      return null;
    }
    final escaped = searchQuery
        .trim()
        .toLowerCase()
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
    return '%$escaped%';
  }

  String? _ftsMatchQuery(String? searchQuery) {
    final trimmed = searchQuery?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final matchQuery = SqliteFtsQuery.toMatchQuery(trimmed);
    return matchQuery.isEmpty ? null : matchQuery;
  }

  String _unifiedFtsEntryIdSubquery() {
    return '''
      SELECT entry_id FROM ${DatabaseConstants.ftsTable}
      WHERE transcript MATCH ?
      UNION
      SELECT entry_id FROM ${DatabaseConstants.graphNodeFtsTable}
      WHERE ${DatabaseConstants.graphNodeFtsTable} MATCH ?
    ''';
  }

  String _unifiedFtsRankSubquery() {
    return '''
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
    ''';
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
        // SQL-7: Legacy full-payload rows (pre-compaction migration 007).
        // Remove once all installed databases have compact column payloads.
        // Tracked: apps/mobile/docs/V1_DATA_FLOW.md (journal SQLite compaction).
        return Right(
          JournalEntry.fromJson(
            payload,
            onDataIssue: _reportEntryDataIssue,
          ),
        );
      }

      return Right(
        JournalEntry.fromJson(
          _mergeColumnsIntoPayload(row, payload),
          onDataIssue: _reportEntryDataIssue,
        ),
      );
    } on Object catch (error, stackTrace) {
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
    return JournalEntry.fromJson(
      {
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
      },
      onDataIssue: _reportEntryDataIssue,
    );
  }

  void _reportEntryDataIssue({
    required String entryId,
    required String issue,
  }) {
    JournalSqliteLog.entryDataIssue(entryId: entryId, issue: issue);
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

/// Cursor for [JournalSqliteRepository.fetchPageAfter].
class JournalFeedCursor {
  const JournalFeedCursor({
    required this.createdAt,
    required this.id,
  });

  final DateTime createdAt;
  final String id;
}