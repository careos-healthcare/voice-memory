import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Keyword and vector retrieval over local memory transcripts.
class MemoryTranscriptSearchRepository {
  MemoryTranscriptSearchRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;

  static const ftsTable = Migration005HybridSearch.ftsTable;
  static const embeddingsTable = Migration005HybridSearch.embeddingsTable;
  static const vecTable = Migration005HybridSearch.vecTable;

  Database get _db => _sqlite.database;

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
  }

  /// BM25-ranked keyword search via FTS5. Returns entry ids best-first.
  Future<List<String>> keywordSearch({
    required String query,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];

    final ftsQuery = _toFtsQuery(trimmed);
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

    return _vectorSearchBlob(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
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

  Future<List<String>> _vectorSearchSqliteVector({
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
          .map((row) => row['entry_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<String>> _vectorSearchLegacyVec0({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    try {
      final rows = await _db.rawQuery(
        '''
        SELECT entry_id
        FROM $vecTable
        WHERE embedding MATCH ?
          AND k = ?
        ORDER BY distance
        ''',
        [_embeddingToBlob(queryEmbedding), limit],
      );
      return rows
          .map((row) => row['entry_id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
    } on Object {
      return const [];
    }
  }

  Future<List<String>> _vectorSearchBlob({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final rows = await _db.query(embeddingsTable, columns: ['entry_id', 'embedding']);
    if (rows.isEmpty) return const [];

    final scored = <({String entryId, double score})>[];
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final blob = row['embedding'] as Uint8List?;
      if (entryId.isEmpty || blob == null) continue;
      final embedding = _blobToEmbedding(blob);
      final score = _cosineSimilarity(queryEmbedding, embedding);
      scored.add((entryId: entryId, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.entryId.compareTo(b.entryId);
    });

    return scored
        .take(limit)
        .map((hit) => hit.entryId)
        .toList(growable: false);
  }

  static String _toFtsQuery(String raw) {
    final tokens = raw
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((token) => token.replaceAll(RegExp(r'[^a-z0-9]+'), ''))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) return '';
    return tokens.map((token) => '"$token"').join(' OR ');
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
