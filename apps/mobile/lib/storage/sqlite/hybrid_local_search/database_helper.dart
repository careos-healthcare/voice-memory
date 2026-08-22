import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/reflection_embedding_inference.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/features/search/semantic_vector_fusion.dart';
import 'package:archiveme_mobile/storage/sqlite/hybrid_local_search/hybrid_search_result_merger.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';

/// Hybrid local search repository helper combining FTS5 keyword retrieval with
/// sqlite-vec [vec0] cosine similarity search.
///
/// Vector storage uses the [Migration005HybridSearch.vecTable] virtual table
/// when the sqlite-vec extension is present (created in migration 005).
/// Search falls back to the bundled sqlite-vector FFI extension, then to an
/// in-process cosine scan over the embedding BLOB table.
final class DatabaseHelper {
  DatabaseHelper({
    required MemoryTranscriptSearchRepository searchRepository,
    required ReflectionEmbeddingInference embeddingInference,
    HybridSearchResultMerger? merger,
  })  : _searchRepository = searchRepository,
        _embeddingInference = embeddingInference,
        _merger = merger ?? const HybridSearchResultMerger();

  final MemoryTranscriptSearchRepository _searchRepository;
  final ReflectionEmbeddingInference _embeddingInference;
  final HybridSearchResultMerger _merger;

  /// True when the legacy sqlite-vec vec0 virtual table is present.
  Future<bool> get hasVec0Table => _searchRepository.hasVec0Table();

  /// Embeds [query] into a 384-d vector suitable for vec0 / cosine search.
  Future<List<double>> embedQuery(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < ReflectionTextProcessor.minTextChars) {
      throw ArgumentError.value(
        query,
        'query',
        'must be at least ${ReflectionTextProcessor.minTextChars} characters',
      );
    }

    final tensor = ReflectionTextProcessor.buildInputTensor(trimmed);
    return _embeddingInference.embed(tensor);
  }

  /// BM25-ranked keyword search over [Migration005HybridSearch.ftsTable].
  Future<List<KeywordSearchHit>> searchKeywords(
    String query, {
    int limit = 20,
  }) async {
    final entryIds = await _searchRepository.keywordSearch(
      query: query,
      limit: limit,
    );

    return entryIds
        .asMap()
        .entries
        .map(
          (entry) => KeywordSearchHit(
            entryId: entry.value,
            rank: entry.key + 1,
          ),
        )
        .toList(growable: false);
  }

  /// Cosine-similarity semantic search via vec0 (when loaded) with fallbacks.
  Future<List<SemanticSearchHit>> searchSemantic(
    List<double> queryEmbedding, {
    int limit = 20,
  }) async {
    final hits = await _searchRepository.vectorSearchWithScores(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );

    return hits
        .asMap()
        .entries
        .map(
          (entry) => SemanticSearchHit(
            entryId: entry.value.entryId,
            rank: entry.key + 1,
            cosineSimilarity: entry.value.cosineSimilarity,
          ),
        )
        .toList(growable: false);
  }

  /// Merges keyword and semantic channels with reciprocal rank fusion.
  List<HybridSearchHit> mergeAndRank({
    required List<KeywordSearchHit> keywordHits,
    required List<SemanticSearchHit> semanticHits,
    int limit = 20,
  }) {
    return _merger.mergeAndRank(
      keywordHits: keywordHits,
      semanticHits: semanticHits,
      limit: limit,
    );
  }

  /// End-to-end hybrid search: embed [query], run SQLite RRF over FTS5 + vec_chunks.
  Future<List<HybridSearchHit>> search(
    String query, {
    int limit = 20,
    int candidateLimit = 50,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || limit <= 0) return const [];

    if (trimmed.length < ReflectionTextProcessor.minTextChars) {
      return searchKeywords(trimmed, limit: limit)
          .then(
            (keywordHits) => mergeAndRank(
              keywordHits: keywordHits,
              semanticHits: const [],
              limit: limit,
            ),
          );
    }

    // Same degrade path the embedding failure below takes, for the same
    // reason: a semantic channel the encoder cannot fill reorders BM25 rather
    // than refining it. See [SemanticVectorFusion].
    if (!SemanticVectorFusion.isEnabledFor(_embeddingInference)) {
      return mergeAndRank(
        keywordHits: await searchKeywords(trimmed, limit: candidateLimit),
        semanticHits: const [],
        limit: limit,
      );
    }

    try {
      final embedding = await embedQuery(trimmed);
      return _searchRepository.hybridSearch(
        keywordQuery: trimmed,
        queryEmbedding: embedding,
        limit: limit,
        candidateLimit: candidateLimit,
        rrfK: _merger.fusionK,
      );
    } on Object {
      return mergeAndRank(
        keywordHits: await searchKeywords(trimmed, limit: candidateLimit),
        semanticHits: const [],
        limit: limit,
      );
    }
  }

  Future<List<SemanticSearchHit>> _searchSemanticForQuery(
    String query,
    int candidateLimit,
  ) async {
    if (query.length < ReflectionTextProcessor.minTextChars) {
      return const [];
    }

    try {
      final embedding = await embedQuery(query);
      return searchSemantic(embedding, limit: candidateLimit);
    } on Object {
      return const [];
    }
  }
}
