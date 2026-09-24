import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/core/execution/isolate_compute_job.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';

/// One stored embedding blob plus its journal entry id.
final class EmbeddingBlobRow {
  const EmbeddingBlobRow({
    required this.entryId,
    required this.blob,
  });

  final String entryId;
  final Uint8List blob;
}

/// Sendable payload for [rankEmbeddingBlobs].
final class EmbeddingBlobRankInput {
  const EmbeddingBlobRankInput({
    required this.queryEmbedding,
    required this.rows,
    required this.limit,
  });

  final List<double> queryEmbedding;
  final List<EmbeddingBlobRow> rows;
  final int limit;
}

/// Cosine-ranks embedding blobs. Top-level so [Isolate.run] / [compute] can
/// serialize the tear-off.
List<VectorSearchHit> rankEmbeddingBlobs(EmbeddingBlobRankInput input) {
  final scored = <VectorSearchHit>[];
  for (final row in input.rows) {
    if (row.entryId.isEmpty || row.blob.isEmpty) continue;
    final embedding = _blobToEmbedding(row.blob);
    scored.add(
      VectorSearchHit(
        entryId: row.entryId,
        cosineSimilarity: _cosineSimilarity(input.queryEmbedding, embedding),
      ),
    );
  }

  scored.sort((a, b) {
    final byScore = b.cosineSimilarity.compareTo(a.cosineSimilarity);
    if (byScore != 0) return byScore;
    return a.entryId.compareTo(b.entryId);
  });

  if (input.limit <= 0) return const [];
  return scored.take(input.limit).toList(growable: false);
}

/// Ranks stored embedding blobs, off the UI isolate when the scan is large.
abstract final class EmbeddingBlobRanker {
  EmbeddingBlobRanker._();

  /// Batches at or above this size pay for [Isolate.run].
  static const isolateRowThreshold = 8;

  static Future<List<VectorSearchHit>> rank({
    required List<double> queryEmbedding,
    required List<EmbeddingBlobRow> rows,
    required int limit,
    ExecutionCancelToken? cancelToken,
    bool forceIsolate = false,
  }) {
    if (rows.isEmpty || limit <= 0) {
      return Future<List<VectorSearchHit>>.value(const []);
    }

    final input = EmbeddingBlobRankInput(
      queryEmbedding: queryEmbedding,
      rows: rows,
      limit: limit,
    );

    return IsolateComputeJob.run<EmbeddingBlobRankInput, List<VectorSearchHit>>(
      label: 'sqlite.vec.blob_rank',
      payload: input,
      computeFn: rankEmbeddingBlobs,
      cancelToken: cancelToken,
      forceInline: !forceIsolate && rows.length < isolateRowThreshold,
    );
  }
}

List<double> _blobToEmbedding(Uint8List blob) {
  final floats = Float32List.view(
    blob.buffer,
    blob.offsetInBytes,
    blob.lengthInBytes ~/ Float32List.bytesPerElement,
  );
  return floats.toList(growable: false);
}

double _cosineSimilarity(List<double> a, List<double> b) {
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
