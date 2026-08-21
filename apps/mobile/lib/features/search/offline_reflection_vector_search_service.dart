import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/local_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_search_guard.dart';
import 'package:archiveme_mobile/features/search/onnx_reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_repository.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_text.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/models/reflection.dart';

/// A semantic similarity hit against locally indexed reflection embeddings.
class ReflectionSearchHit {
  const ReflectionSearchHit({
    required this.entryId,
    required this.cosineSimilarity,
  });

  final String entryId;
  final double cosineSimilarity;
}

/// Offline semantic search over past journal reflections — no cloud calls.
class OfflineReflectionVectorSearchService {
  OfflineReflectionVectorSearchService({
    required ReflectionEmbeddingRepository repository,
    required ReflectionEmbeddingInference inference,
  }) : _repository = repository,
       _inference = inference;

  final ReflectionEmbeddingRepository _repository;
  final ReflectionEmbeddingInference _inference;

  static Future<OfflineReflectionVectorSearchService> create({
    required ReflectionEmbeddingRepository repository,
    ReflectionEmbeddingInference? inferenceOverride,
  }) async {
    final inference =
        inferenceOverride ??
        await OnnxReflectionEmbeddingInference.tryCreateFromAsset() ??
        LocalReflectionEmbeddingInference();
    return OfflineReflectionVectorSearchService(
      repository: repository,
      inference: inference,
    );
  }

  Future<List<double>> embedText(String text) {
    return OfflineReflectionSearchGuard.runOffline(() async {
      final trimmed = text.trim();
      if (trimmed.length < ReflectionTextProcessor.minTextChars) {
        throw ArgumentError.value(text, 'text', 'too short to embed');
      }
      final tensor = ReflectionTextProcessor.buildInputTensor(trimmed);
      return _inference.embed(tensor);
    });
  }

  Future<List<double>> embedReflection(Reflection reflection) {
    return embedText(ReflectionEmbeddingText.fromReflection(reflection));
  }

  Future<List<double>> embedReflectionDto(ReflectionDto reflection) {
    return embedText(ReflectionEmbeddingText.fromReflectionDto(reflection));
  }

  Future<List<ReflectionSearchHit>> searchSimilarText({
    required String query,
    int limit = 20,
  }) async {
    return OfflineReflectionSearchGuard.runOffline(() async {
      final queryEmbedding = await embedText(query);
      final hits = await _repository.vectorSearchWithScores(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      return hits
          .map(
            (hit) => ReflectionSearchHit(
              entryId: hit.entryId,
              cosineSimilarity: hit.cosineSimilarity,
            ),
          )
          .toList(growable: false);
    });
  }

  Future<List<ReflectionSearchHit>> searchSimilarReflection({
    required Reflection reflection,
    int limit = 20,
  }) {
    return searchSimilarText(
      query: ReflectionEmbeddingText.fromReflection(reflection),
      limit: limit,
    );
  }

  Future<List<ReflectionSearchHit>> searchSimilarReflectionDto({
    required ReflectionDto reflection,
    int limit = 20,
  }) {
    return searchSimilarText(
      query: ReflectionEmbeddingText.fromReflectionDto(reflection),
      limit: limit,
    );
  }
}
