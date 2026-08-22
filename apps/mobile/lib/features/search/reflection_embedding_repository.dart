import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_contract.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_vector_support.dart';
import 'package:sqflite/sqflite.dart';

/// Semantic vector index over locally stored reflection embeddings.
class ReflectionEmbeddingRepository {
  ReflectionEmbeddingRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;

  static const embeddingsTable = Migration009ReflectionEmbeddings.embeddingsTable;
  static const vecTable = Migration009ReflectionEmbeddings.vecTable;

  Database get _db => _sqlite.database;

  Future<String?> readContentHash(String entryId) async {
    if (entryId.isEmpty) return null;
    final rows = await _db.query(
      embeddingsTable,
      columns: ['content_hash'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String?;
  }

  Future<void> upsertEmbedding({
    required String entryId,
    required List<double> embedding,
    required String contentHash,
  }) async {
    if (entryId.isEmpty) return;
    if (embedding.length != ReflectionEmbeddingContract.dimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected ${ReflectionEmbeddingContract.dimensions}',
      );
    }

    final nowMillis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final blob = _embeddingToBlob(embedding);
    await _db.insert(
      embeddingsTable,
      {
        'entry_id': entryId,
        'embedding': blob,
        'dimensions': embedding.length,
        'content_hash': contentHash,
        'updated_at': nowMillis,
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

  Future<List<VectorSearchHit>> vectorSearchWithScores({
    required List<double> queryEmbedding,
    int limit = 20,
  }) async {
    if (queryEmbedding.length != ReflectionEmbeddingContract.dimensions) {
      throw ArgumentError.value(
        queryEmbedding.length,
        'queryEmbedding.length',
        'expected ${ReflectionEmbeddingContract.dimensions}',
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

  Future<List<String>> vectorSearch({
    required List<double> queryEmbedding,
    int limit = 20,
  }) async {
    final hits = await vectorSearchWithScores(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
    return hits.map((hit) => hit.entryId).toList(growable: false);
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

  Future<List<VectorSearchHit>> _vectorSearchSqliteVector({
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

  Future<List<VectorSearchHit>> _vectorSearchLegacyVec0({
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
