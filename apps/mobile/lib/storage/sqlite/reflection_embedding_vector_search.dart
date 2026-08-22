import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Cosine similarity search over reflection embedding tables (worker-safe).
abstract final class ReflectionEmbeddingVectorSearch {
  ReflectionEmbeddingVectorSearch._();

  static const embeddingsTable = Migration009ReflectionEmbeddings.embeddingsTable;
  static const vecTable = Migration009ReflectionEmbeddings.vecTable;

  static Future<List<VectorSearchHit>> searchWithScores({
    required Database db,
    required List<double> queryEmbedding,
    int limit = 20,
    String? excludeEntryId,
  }) async {
    if (queryEmbedding.length != ReflectionEmbeddingContract.dimensions) {
      throw ArgumentError.value(
        queryEmbedding.length,
        'queryEmbedding.length',
        'expected ${ReflectionEmbeddingContract.dimensions}',
      );
    }
    if (limit <= 0) return const [];

    final fetchLimit = excludeEntryId == null ? limit : limit + 1;

    List<VectorSearchHit> hits;
    if (SqliteVectorSupport.isAvailable) {
      hits = await _vectorSearchSqliteVector(
        db: db,
        queryEmbedding: queryEmbedding,
        limit: fetchLimit,
      );
    } else if (await _hasLegacyVec0Table(db)) {
      hits = await _vectorSearchLegacyVec0(
        db: db,
        queryEmbedding: queryEmbedding,
        limit: fetchLimit,
      );
    } else {
      hits = await _vectorSearchBlob(
        db: db,
        queryEmbedding: queryEmbedding,
        limit: fetchLimit,
      );
    }

    if (excludeEntryId != null && excludeEntryId.isNotEmpty) {
      hits = hits.where((hit) => hit.entryId != excludeEntryId).toList();
    }

    return hits.take(limit).toList(growable: false);
  }

  static Future<bool> _hasLegacyVec0Table(Database db) async {
    final rows = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table' AND name = ?
      ''',
      [vecTable],
    );
    return rows.isNotEmpty;
  }

  static Future<List<VectorSearchHit>> _vectorSearchSqliteVector({
    required Database db,
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    try {
      final queryLiteral = _vectorLiteral(queryEmbedding);
      final rows = await db.rawQuery(
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
      return _rowsToHits(rows);
    } on Object {
      return const [];
    }
  }

  static Future<List<VectorSearchHit>> _vectorSearchLegacyVec0({
    required Database db,
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    try {
      final rows = await db.rawQuery(
        '''
        SELECT entry_id, distance
        FROM $vecTable
        WHERE embedding MATCH ?
          AND k = ?
        ORDER BY distance
        ''',
        [_embeddingToBlob(queryEmbedding), limit],
      );
      return _rowsToHits(rows);
    } on Object {
      return const [];
    }
  }

  static Future<List<VectorSearchHit>> _vectorSearchBlob({
    required Database db,
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final rows = await db.query(embeddingsTable, columns: ['entry_id', 'embedding']);
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

  static List<VectorSearchHit> _rowsToHits(List<Map<String, Object?>> rows) {
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
