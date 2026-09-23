import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/diagnostics/database_health_service.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_009_reflection_embeddings.dart';
import 'package:sqflite/sqflite.dart';

/// One stored vector kept for a memory-constrained scan.
class VectorStoreRow {
  const VectorStoreRow({required this.id, required this.values});

  final String id;
  final Float32List values;
}

/// A neighbor from the in-memory SIMD scan.
class VectorStoreHit {
  const VectorStoreHit({required this.id, required this.score});

  final String id;
  final double score;
}

/// TurboQuant setup plus a chunked SIMD scan for local vector search.
abstract final class VectorStore {
  /// Exact scalar quantization requested for the embeddings column.
  static const turboQuantStatement =
      "SELECT vector_quantize('embeddings', 'embedding', 'qtype=TURBO,qbits=4')";

  static const String quantOptions = 'qtype=TURBO,qbits=4';

  /// Working set cap for the in-memory scan.
  static const int scanBudgetBytes = 8 * 1024 * 1024;

  static const _tables = <String>[
    'embeddings',
    Migration005HybridSearch.embeddingsTable,
    Migration009ReflectionEmbeddings.embeddingsTable,
  ];

  /// True after [initialize] enables the chunked SIMD scan.
  static bool simdInMemoryScan = true;

  /// Runs TurboQuant when the extension accepts it, then enables SIMD scan.
  static Future<VectorQuantizeReport> initialize(DatabaseExecutor db) async {
    if (db is Database) {
      try {
        await DatabaseHealthService().retainRollingBackup(File(db.path));
      } on Object catch (error) {
        // Quantization continues when the rolling copy cannot be written.
        error.runtimeType;
      }
    }
    final applied = <String, bool>{};
    for (final table in _tables) {
      final statement = table == 'embeddings'
          ? turboQuantStatement
          : "SELECT vector_quantize('$table', 'embedding', '$quantOptions')";
      applied[table] = await _tryQuantize(db, statement);
    }
    simdInMemoryScan = true;
    return VectorQuantizeReport(applied: applied);
  }

  /// Cosine-ranks [rows] with Float32x4, keeping only the top [limit] hits.
  static List<VectorStoreHit> scan({
    required List<VectorStoreRow> rows,
    required Float32List query,
    int limit = 8,
  }) {
    if (!simdInMemoryScan || limit <= 0 || rows.isEmpty || query.isEmpty) {
      return const [];
    }
    final best = <VectorStoreHit>[];
    final chunk = _chunkSize(query.length);
    for (var start = 0; start < rows.length; start += chunk) {
      final end = math.min(start + chunk, rows.length);
      for (var index = start; index < end; index++) {
        final row = rows[index];
        if (row.values.length != query.length) continue;
        final score = _cosine(row.values, query);
        _insert(best, VectorStoreHit(id: row.id, score: score), limit);
      }
    }
    return best;
  }

  static int _chunkSize(int dimensions) {
    final rowBytes = math.max(dimensions, 1) * 4;
    final rows = scanBudgetBytes ~/ rowBytes;
    return math.max(rows, 1);
  }

  static Future<bool> _tryQuantize(DatabaseExecutor db, String statement) async {
    try {
      await db.rawQuery(statement);
      return true;
    } on Object {
      return false;
    }
  }

  static void _insert(List<VectorStoreHit> best, VectorStoreHit hit, int limit) {
    if (best.length < limit) {
      best
        ..add(hit)
        ..sort(_byScore);
      return;
    }
    if (hit.score <= best.last.score) return;
    best[best.length - 1] = hit;
    best.sort(_byScore);
  }

  static int _byScore(VectorStoreHit a, VectorStoreHit b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) return byScore;
    return a.id.compareTo(b.id);
  }

  static double _cosine(Float32List a, Float32List b) {
    var dot = Float32x4.zero();
    var aNorm = Float32x4.zero();
    var bNorm = Float32x4.zero();
    var index = 0;
    final width = a.length - (a.length % 4);
    while (index < width) {
      final left = Float32x4(a[index], a[index + 1], a[index + 2], a[index + 3]);
      final right = Float32x4(b[index], b[index + 1], b[index + 2], b[index + 3]);
      dot += left * right;
      aNorm += left * left;
      bNorm += right * right;
      index += 4;
    }
    var dotSum = dot.x + dot.y + dot.z + dot.w;
    var aSum = aNorm.x + aNorm.y + aNorm.z + aNorm.w;
    var bSum = bNorm.x + bNorm.y + bNorm.z + bNorm.w;
    while (index < a.length) {
      dotSum += a[index] * b[index];
      aSum += a[index] * a[index];
      bSum += b[index] * b[index];
      index += 1;
    }
    if (aSum == 0 || bSum == 0) return 0;
    return dotSum / (math.sqrt(aSum) * math.sqrt(bSum));
  }
}

/// Which embedding tables accepted TurboQuant during [VectorStore.initialize].
class VectorQuantizeReport {
  const VectorQuantizeReport({required this.applied});

  final Map<String, bool> applied;

  bool get anyApplied => applied.values.any((ok) => ok);
}
