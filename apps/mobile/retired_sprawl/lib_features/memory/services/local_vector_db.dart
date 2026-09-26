import 'dart:math' as math;
import 'dart:typed_data';

import 'package:sqflite/sqflite.dart';

/// One transcript chunk stored for semantic search.
class VectorChunk {
  const VectorChunk({
    required this.entryId,
    required this.chunkIndex,
    required this.text,
    required this.startTimeMs,
  });

  final String entryId;
  final int chunkIndex;
  final String text;
  final int startTimeMs;
}

class StoredVector {
  const StoredVector({
    required this.entryId,
    required this.chunkIndex,
    required this.vector,
    required this.modelVersion,
    required this.startTimeMs,
  });

  final String entryId;
  final int chunkIndex;
  final List<double> vector;
  final String modelVersion;
  final int startTimeMs;
}

/// The chunk of another entry closest to a query, with its audio offset.
class VectorHit {
  const VectorHit({
    required this.entryId,
    required this.startTimeMs,
    required this.score,
  });

  final String entryId;
  final int startTimeMs;
  final double score;
}

/// 384-d MiniLM vectors. Other model versions and widths are not compared.
class LocalVectorDb {
  LocalVectorDb(this._db);

  final Database _db;

  static const table = 'entry_vectors';
  static const modelVersion = 'all-MiniLM-L6-v2-384';
  static const dimensions = 384;

  Future<void> ensure() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        entry_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        vector BLOB NOT NULL,
        dimensions INTEGER NOT NULL,
        model_version TEXT NOT NULL,
        start_time_ms INTEGER NOT NULL,
        PRIMARY KEY (entry_id, chunk_index)
      )
    ''');
    await purgeIncompatible();
  }

  /// Drops vectors that were written by another model or width.
  Future<void> purgeIncompatible() async {
    await _db.rawDelete(
      'DELETE FROM $table WHERE model_version != ? OR dimensions != ?',
      [modelVersion, dimensions],
    );
  }

  Future<void> deleteEntry(String entryId) async {
    await ensure();
    await _db.rawDelete(
      'DELETE FROM $table WHERE entry_id = ?',
      [entryId],
    );
  }

  Future<void> write(VectorChunk chunk, List<double> vector) async {
    if (vector.length != dimensions) {
      throw ArgumentError.value(
        vector.length,
        'vector.length',
        'expected $dimensions',
      );
    }
    await ensure();
    await _db.insert(table, {
      'entry_id': chunk.entryId,
      'chunk_index': chunk.chunkIndex,
      'vector': _blob(vector),
      'dimensions': dimensions,
      'model_version': modelVersion,
      'start_time_ms': chunk.startTimeMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StoredVector>> readEntry(String entryId) async {
    await ensure();
    final rows = await _db.query(
      table,
      where: 'entry_id = ? AND model_version = ? AND dimensions = ?',
      whereArgs: [entryId, modelVersion, dimensions],
      orderBy: 'chunk_index ASC',
    );
    return [for (final row in rows) _row(row)].whereType<StoredVector>().toList();
  }

  Future<Set<String>> storedKeys() async {
    await ensure();
    final rows = await _db.query(
      table,
      columns: ['entry_id', 'chunk_index'],
      where: 'model_version = ? AND dimensions = ?',
      whereArgs: [modelVersion, dimensions],
    );
    return {
      for (final row in rows) '${row['entry_id']}:${row['chunk_index']}',
    };
  }

  /// Best chunk of each other entry. Mismatched vectors are ignored.
  Future<List<VectorHit>> nearestToEntry(
    String entryId, {
    int limit = 3,
  }) async {
    await ensure();
    final rows = await _db.query(table);
    final stored = [
      for (final row in rows) _row(row),
    ].whereType<StoredVector>();
    final mine = stored.where((row) => row.entryId == entryId).toList();
    if (mine.isEmpty) return const [];
    final query = mine.first.vector;
    final best = <String, VectorHit>{};
    for (final row in stored) {
      if (row.entryId == entryId) continue;
      final score = cosine(query, row);
      if (score == null) continue;
      final current = best[row.entryId];
      if (current != null && current.score >= score) continue;
      best[row.entryId] = VectorHit(
        entryId: row.entryId,
        startTimeMs: row.startTimeMs,
        score: score,
      );
    }
    final hits = best.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (hits.length <= limit) return hits;
    return hits.sublist(0, limit);
  }

  /// Cosine of two current-model vectors. Anything else is left uncompared.
  static double? cosine(List<double> query, StoredVector candidate) {
    if (candidate.modelVersion != modelVersion) return null;
    if (query.length != dimensions || candidate.vector.length != dimensions) {
      return null;
    }
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < dimensions; i++) {
      dot += query[i] * candidate.vector[i];
      normA += query[i] * query[i];
      normB += candidate.vector[i] * candidate.vector[i];
    }
    if (normA == 0 || normB == 0) return 0;
    return dot / (math.sqrt(normA) * math.sqrt(normB));
  }

  static StoredVector? _row(Map<String, Object?> row) {
    final blob = row['vector'];
    if (blob is! Uint8List) return null;
    return StoredVector(
      entryId: row['entry_id'] as String? ?? '',
      chunkIndex: row['chunk_index'] as int? ?? 0,
      vector: _vector(blob),
      modelVersion: row['model_version'] as String? ?? '',
      startTimeMs: row['start_time_ms'] as int? ?? 0,
    );
  }

  static Uint8List _blob(List<double> vector) {
    final floats = Float32List.fromList(vector);
    return Uint8List.view(
      floats.buffer,
      floats.offsetInBytes,
      floats.lengthInBytes,
    );
  }

  static List<double> _vector(Uint8List blob) {
    final floats = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ Float32List.bytesPerElement,
    );
    return floats.toList(growable: false);
  }
}
