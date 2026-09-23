import 'dart:typed_data';

import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_015_vec_chunks.dart';
import 'package:sqflite/sqflite.dart';

/// One sqlite-vec distance for an entry.
class VecDistanceHit {
  const VecDistanceHit({required this.entryId, required this.distance});

  final String entryId;
  final double distance;
}

/// A moment ranked by vector distance and entity-graph weight.
class HybridEntityHit {
  const HybridEntityHit({
    required this.entryId,
    required this.score,
    required this.graphWeight,
    this.vectorDistance,
  });

  final String entryId;
  final double score;
  final double graphWeight;
  final double? vectorDistance;
}

/// Loads nearest entries from sqlite-vec. Tests can replace this.
typedef VecDistanceLoader =
    Future<List<VecDistanceHit>> Function(
      DatabaseExecutor db,
      Uint8List query,
      int limit,
    );

/// Hybrid retrieval: sqlite-vec distance plus one hop through the entity graph.
class VecSearchService {
  const VecSearchService({this.loadDistances = loadVecDistances});

  final VecDistanceLoader loadDistances;

  static const String vecTable = Migration015VecChunks.vecChunksTable;

  Future<List<HybridEntityHit>> search({
    required DatabaseExecutor db,
    required List<double> queryEmbedding,
    List<String> entityIds = const [],
    int limit = 20,
  }) async {
    if (limit <= 0) return const [];
    final distances = queryEmbedding.isEmpty
        ? const <VecDistanceHit>[]
        : await loadDistances(
            db,
            _embeddingToBlob(queryEmbedding),
            limit,
          );
    final graph = await _graphWeights(db, entityIds);
    final scores = <String, _Score>{};
    for (final hit in distances) {
      scores.putIfAbsent(hit.entryId, _Score.new)
        ..distance = hit.distance
        ..vector = 1 / (1 + hit.distance);
    }
    for (final entry in graph.entries) {
      scores.putIfAbsent(entry.key, _Score.new).graph = entry.value;
    }
    final ranked = scores.entries.map((entry) {
      final score = entry.value;
      return HybridEntityHit(
        entryId: entry.key,
        score: score.vector + score.graph,
        graphWeight: score.graph,
        vectorDistance: score.distance,
      );
    }).toList()..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.entryId.compareTo(b.entryId);
    });
    return ranked.take(limit).toList(growable: false);
  }

  static Future<List<VecDistanceHit>> loadVecDistances(
    DatabaseExecutor db,
    Uint8List query,
    int limit,
  ) async {
    try {
      final rows = await db.rawQuery(
        '''
        SELECT entry_id, distance
        FROM $vecTable
        WHERE embedding MATCH ?
          AND k = ?
        ORDER BY distance
        ''',
        [query, limit],
      );
      return [
        for (final row in rows)
          if ((row['entry_id'] as String?)?.isNotEmpty ?? false)
            VecDistanceHit(
              entryId: row['entry_id']! as String,
              distance: (row['distance'] as num?)?.toDouble() ?? 0,
            ),
      ];
    } on Object {
      return const [];
    }
  }

  Future<Map<String, double>> _graphWeights(
    DatabaseExecutor db,
    List<String> entityIds,
  ) async {
    final seeds = entityIds.where((id) => id.isNotEmpty).toSet();
    if (seeds.isEmpty) return const {};
    final neighbors = await _neighborWeights(db, seeds);
    final expanded = {...seeds, ...neighbors.keys};
    final marks = List.filled(expanded.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT entry_id, entity_id
      FROM ${EntityExtractionWorker.entryEntitiesTable}
      WHERE entity_id IN ($marks)
      ''',
      expanded.toList(),
    );
    final weights = <String, double>{};
    for (final row in rows) {
      final entryId = row['entry_id'] as String? ?? '';
      final entityId = row['entity_id'] as String? ?? '';
      if (entryId.isEmpty || entityId.isEmpty) continue;
      final boost = seeds.contains(entityId)
          ? 1.0
          : (neighbors[entityId] ?? 0) * 0.5;
      weights[entryId] = (weights[entryId] ?? 0) + boost;
    }
    return weights;
  }

  Future<Map<String, double>> _neighborWeights(
    DatabaseExecutor db,
    Set<String> seeds,
  ) async {
    final marks = List.filled(seeds.length, '?').join(', ');
    final args = seeds.toList();
    final rows = await db.rawQuery(
      '''
      SELECT target_id AS entity_id, weight
      FROM ${EntityExtractionWorker.relationshipsTable}
      WHERE source_id IN ($marks)
      UNION ALL
      SELECT source_id AS entity_id, weight
      FROM ${EntityExtractionWorker.relationshipsTable}
      WHERE target_id IN ($marks)
      ''',
      [...args, ...args],
    );
    final weights = <String, double>{};
    for (final row in rows) {
      final entityId = row['entity_id'] as String? ?? '';
      if (entityId.isEmpty || seeds.contains(entityId)) continue;
      final weight = (row['weight'] as num?)?.toDouble() ?? 0;
      final current = weights[entityId] ?? 0;
      if (weight > current) weights[entityId] = weight;
    }
    return weights;
  }

  static Uint8List _embeddingToBlob(List<double> embedding) {
    final bytes = ByteData(embedding.length * 4);
    for (var i = 0; i < embedding.length; i++) {
      bytes.setFloat32(i * 4, embedding[i], Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}

class _Score {
  double vector = 0;
  double graph = 0;
  double? distance;
}
