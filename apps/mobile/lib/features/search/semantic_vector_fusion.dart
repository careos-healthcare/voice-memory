import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:flutter/foundation.dart';

/// Whether the vector leg may be fused with FTS5 BM25 results.
///
/// Off by default, and the reason is the encoder rather than the fusion.
/// `OnnxReflectionEmbeddingInference.tryCreateFromAsset()` returns null
/// whenever `assets/models/` holds no encoder, which is every build in this
/// tree — `pubspec.yaml` declares one asset and it is `config/backend_url.txt`.
/// Every embedding site therefore resolves to
/// `LocalReflectionEmbeddingInference`, a fixed random projection over a tensor
/// that stores the FNV hash of the i-th word at index i. That encodes word
/// position, so two wordings of the same thought land nowhere near each other
/// and the vector is dominated by whichever word hashed largest.
///
/// Reciprocal rank fusion has no way to tell a weak leg from a wrong one: it
/// adds `1 / (k + rank)` from each list, so a keyword hit that BM25 ranked
/// first is overtaken by a document the noise leg happened to rank first.
/// Dropping the leg leaves BM25 ranking intact instead of perturbing it.
///
/// Exact-duplicate detection is deliberately unaffected. Identical text
/// produces an identical tensor and therefore an identical vector, so
/// duplicate and near-duplicate work — `ReflectionEmbeddingVectorSearch`,
/// `MemoryTranscriptSearchRepository.vectorSearch*` and the automated-graph
/// edges in `EmbeddingIndexWorkerService` — keeps calling vector search
/// directly and is not routed through this flag.
///
/// To re-enable when a real encoder ships: add the encoder asset, then build
/// with `--dart-define=ARCHIVEME_SEMANTIC_VECTOR_FUSION=true`. Call sites that
/// hold the encoder go through [isEnabledFor] and so need both; the define
/// alone is not enough for them. `HybridSearchEngine` is handed a finished
/// vector rather than an encoder and can only read [enabled], so the define
/// alone does turn its leg back on — set it once the asset is in place.
abstract final class SemanticVectorFusion {
  SemanticVectorFusion._();

  static const bool enabledByBuild = bool.fromEnvironment(
    'ARCHIVEME_SEMANTIC_VECTOR_FUSION',
  );

  /// Lets host-VM tests exercise the fused path without a build flag.
  @visibleForTesting
  static bool? debugEnabled;

  static bool get enabled => debugEnabled ?? enabledByBuild;

  /// [enabled] plus the encoder's own answer, for call sites holding one.
  static bool isEnabledFor(ReflectionEmbeddingInference inference) =>
      enabled && inference.producesSemanticVectors;
}
