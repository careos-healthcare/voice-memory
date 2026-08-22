import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/insight_engine/reciprocal_rank_fusion.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_015_vec_chunks.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_fts_query.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vec_support.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Keyword and vector retrieval over local memory transcripts.
class MemoryTranscriptSearchRepository {
  MemoryTranscriptSearchRepository(AppSqliteDatabase sqlite)
      : _db = sqlite.database;

  MemoryTranscriptSearchRepository.fromWorkerDatabase(Database db) : _db = db;

  final Database _db;

  static const ftsTable = Migration005HybridSearch.ftsTable;
  static const embeddingsTable = Migration005HybridSearch.embeddingsTable;
  static const vecTable = Migration005HybridSearch.vecTable;
  static const vecChunksTable = Migration015VecChunks.vecChunksTable;

  static const _defaultRrfK = 60;

  Future<void> upsertEmbedding({
    required String entryId,
    required List<double> embedding,
  }) async {
    if (entryId.isEmpty) return;
    if (embedding.length != localTranscriptEmbeddingDimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected $localTranscriptEmbeddingDimensions dimensions',
      );
    }

    final blob = _embeddingToBlob(embedding);
    await _db.insert(
      embeddingsTable,
      {
        'entry_id': entryId,
        'embedding': blob,
        'dimensions': embedding.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _hasLegacyVec0Table()) {
      await _upsertLegacyVec0(entryId: entryId, embedding: embedding);
    }
    if (await _hasVecChunksTable()) {
      await _upsertVecChunks(entryId: entryId, embedding: embedding);
    }
  }

  Future<void> deleteEmbedding(String entryId) async {
    if (entryId.isEmpty) return;
    await _db.delete(
      embeddingsTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    if (await _hasLegacyVec0Table()) {
      await _db.delete(
        vecTable,
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
    }
    if (await _hasVecChunksTable()) {
      await _db.delete(
        vecChunksTable,
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
    }
  }

  /// BM25-ranked keyword search via FTS5. Returns entry ids best-first.
  Future<List<String>> keywordSearch({
    required String query,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];

    final ftsQuery = SqliteFtsQuery.toMatchQuery(trimmed);
    if (ftsQuery.isEmpty) return const [];

    final rows = await _db.rawQuery(
      '''
      SELECT entry_id
      FROM $ftsTable
      WHERE $ftsTable MATCH ?
      ORDER BY bm25($ftsTable)
      LIMIT ?
      ''',
      [ftsQuery, limit],
    );

    return rows
        .map((row) => row['entry_id'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  /// Cosine-similarity vector search. Returns entry ids best-first.
  Future<List<String>> vectorSearch({
    required List<double> queryEmbedding,
    int limit = 20,
  }) async {
    if (queryEmbedding.length != localTranscriptEmbeddingDimensions) {
      throw ArgumentError.value(
        queryEmbedding.length,
        'queryEmbedding.length',
        'expected $localTranscriptEmbeddingDimensions dimensions',
      );
    }
    if (limit <= 0) return const [];

    if (SqliteVectorSupport.isAvailable) {
      final sqliteVectorHits = await _vectorSearchSqliteVector(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      if (sqliteVectorHits.isNotEmpty) return sqliteVectorHits;
    }

    if (await _hasLegacyVec0Table()) {
      final vecHits = await _vectorSearchLegacyVec0(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      if (vecHits.isNotEmpty) return vecHits;
    }

    final blobHits = await _vectorSearchBlob(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
    return blobHits.map((hit) => hit.entryId).toList(growable: false);
  }

  /// Cosine-similarity search with explicit scores (for X-Ray inspection).
  Future<List<VectorSearchHit>> vectorSearchWithScores({
    required List<double> queryEmbedding,
    int limit = 20,
  }) async {
    if (queryEmbedding.length != localTranscriptEmbeddingDimensions) {
      throw ArgumentError.value(
        queryEmbedding.length,
        'queryEmbedding.length',
        'expected $localTranscriptEmbeddingDimensions dimensions',
      );
    }
    if (limit <= 0) return const [];

    if (SqliteVectorSupport.isAvailable) {
      final sqliteVectorHits = await _vectorSearchSqliteVectorWithScores(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      if (sqliteVectorHits.isNotEmpty) return sqliteVectorHits;
    }

    if (await _hasLegacyVec0Table()) {
      final vecHits = await _vectorSearchLegacyVec0WithScores(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      if (vecHits.isNotEmpty) return vecHits;
    }

    return _vectorSearchBlob(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
  }

  /// Hybrid FTS5 + vec_chunks search with Reciprocal Rank Fusion entirely in SQLite.
  ///
  /// Falls back to sqlite-vector [vector_full_scan] or in-process RRF when
  /// [vecChunksTable] is unavailable (e.g. unit tests without native extensions).
  Future<List<HybridSearchHit>> hybridSearch({
    required String keywordQuery,
    required List<double> queryEmbedding,
    int limit = 20,
    int candidateLimit = 50,
    int rrfK = _defaultRrfK,
  }) async {
    if (limit <= 0) return const [];

    final trimmed = keywordQuery.trim();
    final ftsQuery =
        trimmed.isEmpty ? '' : SqliteFtsQuery.toMatchQuery(trimmed);
    final hasKeyword = ftsQuery.isNotEmpty;
    final hasVector =
        queryEmbedding.length == localTranscriptEmbeddingDimensions;

    if (!hasKeyword && !hasVector) return const [];

    if (hasKeyword && !hasVector) {
      final keywordIds = await keywordSearch(
        query: trimmed,
        limit: limit,
      );
      return _hitsFromKeywordOnly(keywordIds, limit, rrfK);
    }

    if (!hasKeyword && hasVector) {
      final vectorHits = await vectorSearchWithScores(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      return _hitsFromVectorOnly(vectorHits, limit, rrfK);
    }

    if (await _hasVecChunksTable()) {
      final sqlHits = await _hybridSearchSqlVecChunks(
        ftsQuery: ftsQuery,
        queryEmbedding: queryEmbedding,
        limit: limit,
        candidateLimit: candidateLimit,
        rrfK: rrfK,
      );
      if (sqlHits.isNotEmpty) return sqlHits;
    }

    if (SqliteVectorSupport.isAvailable) {
      final sqlHits = await _hybridSearchSqlVectorFullScan(
        ftsQuery: ftsQuery,
        queryEmbedding: queryEmbedding,
        limit: limit,
        candidateLimit: candidateLimit,
        rrfK: rrfK,
      );
      if (sqlHits.isNotEmpty) return sqlHits;
    }

    return _hybridSearchDartFallback(
      keywordQuery: trimmed,
      queryEmbedding: queryEmbedding,
      limit: limit,
      candidateLimit: candidateLimit,
      rrfK: rrfK,
    );
  }

  /// Loads stored embeddings for [entryIds] (missing ids are skipped).
  Future<Map<String, List<double>>> loadEmbeddingsFor(
    Iterable<String> entryIds,
  ) async {
    final ids = entryIds.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return const {};

    final placeholders = List.filled(ids.length, '?').join(', ');
    final rows = await _db.rawQuery(
      '''
      SELECT entry_id, embedding
      FROM $embeddingsTable
      WHERE entry_id IN ($placeholders)
      ''',
      ids.toList(growable: false),
    );

    final out = <String, List<double>>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final blob = row['embedding'] as Uint8List?;
      if (entryId.isEmpty || blob == null) continue;
      out[entryId] = _blobToEmbedding(blob);
    }
    return out;
  }

  /// True when the legacy sqlite-vec [vecTable] virtual table is present.
  Future<bool> hasVec0Table() => _hasLegacyVec0Table();

  /// True when the [vecChunksTable] sqlite-vec virtual table is present.
  Future<bool> hasVecChunksTable() => _hasVecChunksTable();

  Future<bool> _hasVecChunksTable() => SqliteVecSupport.hasVecChunksTable(_db);

  Future<bool> _hasLegacyVec0Table() async {
    final rows = await _db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      ''',
      [vecTable],
    );
    return rows.isNotEmpty;
  }

  Future<void> _upsertLegacyVec0({
    required String entryId,
    required List<double> embedding,
  }) async {
    await _db.delete(
      vecTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    await _db.insert(vecTable, {
      'entry_id': entryId,
      'embedding': _embeddingToBlob(embedding),
    });
  }

  Future<void> _upsertVecChunks({
    required String entryId,
    required List<double> embedding,
  }) async {
    await _db.delete(
      vecChunksTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    await _db.insert(vecChunksTable, {
      'entry_id': entryId,
      'embedding': _embeddingToBlob(embedding),
    });
  }

  Future<List<HybridSearchHit>> _hybridSearchSqlVecChunks({
    required String ftsQuery,
    required List<double> queryEmbedding,
    required int limit,
    required int candidateLimit,
    required int rrfK,
  }) async {
    try {
      final rows = await _db.rawQuery(
        '''
        WITH fts_ranked AS (
          SELECT
            entry_id,
            ROW_NUMBER() OVER (ORDER BY bm25($ftsTable)) AS rnk
          FROM $ftsTable
          WHERE $ftsTable MATCH ?
          LIMIT ?
        ),
        vec_ranked AS (
          SELECT
            entry_id,
            ROW_NUMBER() OVER (ORDER BY distance ASC) AS rnk
          FROM (
            SELECT entry_id, distance
            FROM $vecChunksTable
            WHERE embedding MATCH ?
              AND k = ?
            ORDER BY distance
            LIMIT ?
          )
        ),
        combined AS (
          SELECT entry_id, rnk FROM fts_ranked
          UNION ALL
          SELECT entry_id, rnk FROM vec_ranked
        ),
        rrf AS (
          SELECT
            entry_id,
            SUM(1.0 / (? + rnk)) AS score
          FROM combined
          GROUP BY entry_id
        )
        SELECT
          r.entry_id AS entry_id,
          r.score AS score,
          f.rnk AS keyword_rank,
          v.rnk AS vector_rank
        FROM rrf AS r
        LEFT JOIN fts_ranked AS f ON f.entry_id = r.entry_id
        LEFT JOIN vec_ranked AS v ON v.entry_id = r.entry_id
        ORDER BY r.score DESC, r.entry_id ASC
        LIMIT ?
        ''',
        [
          ftsQuery,
          candidateLimit,
          _embeddingToBlob(queryEmbedding),
          candidateLimit,
          candidateLimit,
          rrfK,
          limit,
        ],
      );
      return _mapHybridSearchRows(rows);
    } on Object {
      return const [];
    }
  }

  Future<List<HybridSearchHit>> _hybridSearchSqlVectorFullScan({
    required String ftsQuery,
    required List<double> queryEmbedding,
    required int limit,
    required int candidateLimit,
    required int rrfK,
  }) async {
    try {
      final queryLiteral = _vectorLiteral(queryEmbedding);
      final rows = await _db.rawQuery(
        '''
        WITH fts_ranked AS (
          SELECT
            entry_id,
            ROW_NUMBER() OVER (ORDER BY bm25($ftsTable)) AS rnk
          FROM $ftsTable
          WHERE $ftsTable MATCH ?
          LIMIT ?
        ),
        vec_ranked AS (
          SELECT
            entry_id,
            ROW_NUMBER() OVER (ORDER BY distance ASC) AS rnk
          FROM (
            SELECT e.entry_id AS entry_id, v.distance AS distance
            FROM $embeddingsTable AS e
            JOIN vector_full_scan(
              '$embeddingsTable',
              'embedding',
              vector_as_f32(?),
              ?
            ) AS v ON e.rowid = v.rowid
            ORDER BY v.distance
            LIMIT ?
          )
        ),
        combined AS (
          SELECT entry_id, rnk FROM fts_ranked
          UNION ALL
          SELECT entry_id, rnk FROM vec_ranked
        ),
        rrf AS (
          SELECT
            entry_id,
            SUM(1.0 / (? + rnk)) AS score
          FROM combined
          GROUP BY entry_id
        )
        SELECT
          r.entry_id AS entry_id,
          r.score AS score,
          f.rnk AS keyword_rank,
          v.rnk AS vector_rank
        FROM rrf AS r
        LEFT JOIN fts_ranked AS f ON f.entry_id = r.entry_id
        LEFT JOIN vec_ranked AS v ON v.entry_id = r.entry_id
        ORDER BY r.score DESC, r.entry_id ASC
        LIMIT ?
        ''',
        [
          ftsQuery,
          candidateLimit,
          queryLiteral,
          candidateLimit,
          candidateLimit,
          rrfK,
          limit,
        ],
      );
      return _mapHybridSearchRows(rows);
    } on Object {
      return const [];
    }
  }

  Future<List<HybridSearchHit>> _hybridSearchDartFallback({
    required String keywordQuery,
    required List<double> queryEmbedding,
    required int limit,
    required int candidateLimit,
    required int rrfK,
  }) async {
    const fusion = ReciprocalRankFusion();
    final keywordIds = await keywordSearch(
      query: keywordQuery,
      limit: candidateLimit,
    );
    final vectorHits = await vectorSearchWithScores(
      queryEmbedding: queryEmbedding,
      limit: candidateLimit,
    );
    final vectorIds =
        vectorHits.map((hit) => hit.entryId).toList(growable: false);

    if (keywordIds.isEmpty && vectorIds.isEmpty) return const [];

    final effectiveFusion = rrfK == fusion.k
        ? fusion
        : ReciprocalRankFusion(k: rrfK);
    final fusedIds = effectiveFusion.fuse(
      [keywordIds, vectorIds],
      limit: limit,
    );

    final keywordRankById = {
      for (var i = 0; i < keywordIds.length; i++) keywordIds[i]: i + 1,
    };
    final vectorRankById = {
      for (var i = 0; i < vectorIds.length; i++) vectorIds[i]: i + 1,
    };

    final fusedScores = <String, double>{};
    for (final list in [keywordIds, vectorIds]) {
      for (var index = 0; index < list.length; index++) {
        final entryId = list[index];
        fusedScores[entryId] =
            (fusedScores[entryId] ?? 0) + 1 / (rrfK + index + 1);
      }
    }

    return fusedIds
        .map(
          (entryId) => HybridSearchHit(
            entryId: entryId,
            score: fusedScores[entryId] ?? 0,
            keywordRank: keywordRankById[entryId],
            vectorRank: vectorRankById[entryId],
          ),
        )
        .toList(growable: false);
  }

  List<HybridSearchHit> _hitsFromKeywordOnly(
    List<String> entryIds,
    int limit,
    int rrfK,
  ) {
    return entryIds
        .take(limit)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => HybridSearchHit(
            entryId: entry.value,
            score: 1 / (rrfK + entry.key + 1),
            keywordRank: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  List<HybridSearchHit> _hitsFromVectorOnly(
    List<VectorSearchHit> vectorHits,
    int limit,
    int rrfK,
  ) {
    return vectorHits
        .take(limit)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => HybridSearchHit(
            entryId: entry.value.entryId,
            score: 1 / (rrfK + entry.key + 1),
            vectorRank: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  List<HybridSearchHit> _mapHybridSearchRows(List<Map<String, Object?>> rows) {
    return rows
        .map((row) {
          final entryId = row['entry_id'] as String? ?? '';
          if (entryId.isEmpty) return null;
          return HybridSearchHit(
            entryId: entryId,
            score: (row['score'] as num?)?.toDouble() ?? 0,
            keywordRank: (row['keyword_rank'] as num?)?.toInt(),
            vectorRank: (row['vector_rank'] as num?)?.toInt(),
          );
        })
        .whereType<HybridSearchHit>()
        .toList(growable: false);
  }

  Future<List<String>> _vectorSearchSqliteVector({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final hits = await _vectorSearchSqliteVectorWithScores(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
    return hits.map((hit) => hit.entryId).toList(growable: false);
  }

  Future<List<VectorSearchHit>> _vectorSearchSqliteVectorWithScores({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    try {
      final queryLiteral = _vectorLiteral(queryEmbedding);
      final rows = await _db.rawQuery(
        '''
        SELECT e.entry_id AS entry_id, v.distance AS distance
        FROM $embeddingsTable AS e
        JOIN vector_full_scan(
          '$embeddingsTable',
          'embedding',
          vector_as_f32(?),
          ?
        ) AS v ON e.rowid = v.rowid
        ORDER BY v.distance
        ''',
        [queryLiteral, limit],
      );
      return rows
          .map((row) {
            final entryId = row['entry_id'] as String? ?? '';
            final distance = (row['distance'] as num?)?.toDouble() ?? 1;
            if (entryId.isEmpty) return null;
            return VectorSearchHit(
              entryId: entryId,
              cosineSimilarity: 1 - distance,
            );
          })
          .whereType<VectorSearchHit>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<String>> _vectorSearchLegacyVec0({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final hits = await _vectorSearchLegacyVec0WithScores(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
    return hits.map((hit) => hit.entryId).toList(growable: false);
  }

  Future<List<VectorSearchHit>> _vectorSearchLegacyVec0WithScores({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT entry_id, distance
        FROM $vecTable
        WHERE embedding MATCH ?
          AND k = ?
        ORDER BY distance
        ''',
        [_embeddingToBlob(queryEmbedding), limit],
      );
      return rows
          .map((row) {
            final entryId = row['entry_id'] as String? ?? '';
            final distance = (row['distance'] as num?)?.toDouble() ?? 1;
            if (entryId.isEmpty) return null;
            return VectorSearchHit(
              entryId: entryId,
              cosineSimilarity: 1 - distance,
            );
          })
          .whereType<VectorSearchHit>()
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<VectorSearchHit>> _vectorSearchBlob({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final rows = await _db.query(embeddingsTable, columns: ['entry_id', 'embedding']);
    if (rows.isEmpty) return const [];

    final scored = <VectorSearchHit>[];
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final blob = row['embedding'] as Uint8List?;
      if (entryId.isEmpty || blob == null) continue;
      final embedding = _blobToEmbedding(blob);
      final score = _cosineSimilarity(queryEmbedding, embedding);
      scored.add(VectorSearchHit(entryId: entryId, cosineSimilarity: score));
    }

    scored.sort((a, b) {
      final byScore = b.cosineSimilarity.compareTo(a.cosineSimilarity);
      if (byScore != 0) return byScore;
      return a.entryId.compareTo(b.entryId);
    });

    return scored.take(limit).toList(growable: false);
  }

  static String _vectorLiteral(List<double> embedding) {
    final values = embedding.map((value) => value.toString()).join(', ');
    return '[$values]';
  }

  static Uint8List _embeddingToBlob(List<double> embedding) {
    final bytes = Float32List.fromList(embedding);
    return bytes.buffer.asUint8List();
  }

  static List<double> _blobToEmbedding(Uint8List blob) {
    final floats = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.toList(growable: false);
  }

  static double _cosineSimilarity(List<double> a, List<double> b) {
    final length = math.min(a.length, b.length);
    if (length == 0) return 0;

    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }
}
