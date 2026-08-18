import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_006_image_embeddings.dart';
import 'package:sqflite/sqflite.dart';

/// Vector retrieval and persistence for journal photo attachments.
class ImageAttachmentEmbeddingRepository {
  ImageAttachmentEmbeddingRepository(this._sqlite);

  final AppSqliteDatabase _sqlite;

  static const embeddingsTable = Migration006ImageEmbeddings.embeddingsTable;
  static const vecTable = Migration006ImageEmbeddings.vecTable;

  Database get _db => _sqlite.database;

  Future<void> upsertEmbedding({
    required String evidenceId,
    required String entryId,
    required List<double> embedding,
  }) async {
    if (evidenceId.isEmpty || entryId.isEmpty) return;
    if (embedding.length != imageEmbeddingDimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected $imageEmbeddingDimensions dimensions',
      );
    }

    final blob = _embeddingToBlob(embedding);
    await _db.insert(
      embeddingsTable,
      {
        'evidence_id': evidenceId,
        'entry_id': entryId,
        'embedding': blob,
        'dimensions': embedding.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _hasVec0Table()) {
      await _upsertVec0(
        evidenceId: evidenceId,
        entryId: entryId,
        embedding: embedding,
      );
    }
  }

  Future<void> deleteEmbedding(String evidenceId) async {
    if (evidenceId.isEmpty) return;
    await _db.delete(
      embeddingsTable,
      where: 'evidence_id = ?',
      whereArgs: [evidenceId],
    );
    if (await _hasVec0Table()) {
      await _db.delete(
        vecTable,
        where: 'evidence_id = ?',
        whereArgs: [evidenceId],
      );
    }
  }

  Future<void> deleteEmbeddingsForEntry(String entryId) async {
    if (entryId.isEmpty) return;
    await _db.delete(
      embeddingsTable,
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    if (await _hasVec0Table()) {
      await _db.delete(
        vecTable,
        where: 'entry_id = ?',
        whereArgs: [entryId],
      );
    }
  }

  /// Cosine-similarity search over image attachments. Returns journal entry ids.
  Future<List<String>> vectorSearchByEntry({
    required List<double> queryEmbedding,
    int limit = 20,
  }) async {
    if (queryEmbedding.length != imageEmbeddingDimensions) {
      throw ArgumentError.value(
        queryEmbedding.length,
        'queryEmbedding.length',
        'expected $imageEmbeddingDimensions dimensions',
      );
    }
    if (limit <= 0) return const [];

    if (await _hasVec0Table()) {
      final vecHits = await _vectorSearchVec0(
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

  Future<bool> _hasVec0Table() async {
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

  Future<void> _upsertVec0({
    required String evidenceId,
    required String entryId,
    required List<double> embedding,
  }) async {
    await _db.delete(
      vecTable,
      where: 'evidence_id = ?',
      whereArgs: [evidenceId],
    );
    await _db.insert(vecTable, {
      'evidence_id': evidenceId,
      'entry_id': entryId,
      'embedding': _embeddingToBlob(embedding),
    });
  }

  Future<List<String>> _vectorSearchVec0({
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
        [_embeddingToBlob(queryEmbedding), limit * 4],
      );

      return _dedupeEntryIds(rows, limit);
    } on Object {
      return const [];
    }
  }

  Future<List<String>> _vectorSearchBlob({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final rows = await _db.query(
      embeddingsTable,
      columns: ['entry_id', 'embedding'],
    );
    if (rows.isEmpty) return const [];

    final bestByEntry = <String, double>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final blob = row['embedding'] as Uint8List?;
      if (entryId.isEmpty || blob == null) continue;
      final embedding = _blobToEmbedding(blob);
      final score = _cosineSimilarity(queryEmbedding, embedding);
      final existing = bestByEntry[entryId];
      if (existing == null || score > existing) {
        bestByEntry[entryId] = score;
      }
    }

    final ranked = bestByEntry.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        return a.key.compareTo(b.key);
      });

    return ranked.take(limit).map((entry) => entry.key).toList(growable: false);
  }

  List<String> _dedupeEntryIds(List<Map<String, Object?>> rows, int limit) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      if (entryId.isEmpty || seen.contains(entryId)) continue;
      seen.add(entryId);
      ordered.add(entryId);
      if (ordered.length >= limit) break;
    }
    return ordered;
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
