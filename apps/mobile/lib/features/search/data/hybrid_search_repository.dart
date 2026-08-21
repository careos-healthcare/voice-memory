import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/search/data/embedded_node.dart';
import 'package:archiveme_mobile/objectbox.g.dart';
import 'package:archiveme_mobile/storage/sqlite/hybrid_local_search/hybrid_search_result_merger.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';

/// Hybrid retrieval combining SQLite FTS5 lexical search with ObjectBox HNSW
/// semantic search, merged via reciprocal rank fusion (RRF).
final class HybridSearchRepository {
  HybridSearchRepository({
    required MemoryTranscriptSearchRepository lexicalSearch,
    required Box<EmbeddedNode> embeddedNodeBox,
    HybridSearchResultMerger? merger,
  })  : _lexicalSearch = lexicalSearch,
        _embeddedNodeBox = embeddedNodeBox,
        _merger = merger ?? const HybridSearchResultMerger();

  final MemoryTranscriptSearchRepository _lexicalSearch;
  final Box<EmbeddedNode> _embeddedNodeBox;
  final HybridSearchResultMerger _merger;

  /// Persists a 384-d embedding into the on-device HNSW index.
  Future<void> upsertEmbedding({
    required String entryId,
    required List<double> embedding,
  }) async {
    if (entryId.isEmpty) return;
    if (embedding.length != localTranscriptEmbeddingDimensions) {
      throw ArgumentError.value(
        embedding.length,
        'embedding.length',
        'expected $localTranscriptEmbeddingDimensions dimensions',
      );
    }

    _embeddedNodeBox.put(
      EmbeddedNode(entryId: entryId, embedding: embedding),
    );
  }

  /// Removes an entry from the HNSW index.
  Future<void> deleteEmbedding(String entryId) async {
    if (entryId.isEmpty) return;

    final query =
        _embeddedNodeBox.query(EmbeddedNode_.entryId.equals(entryId)).build();
    try {
      final nodes = query.find();
      if (nodes.isEmpty) return;
      _embeddedNodeBox.removeMany(nodes.map((node) => node.id).toList());
    } finally {
      query.close();
    }
  }

  /// Runs FTS5 and HNSW retrieval concurrently, then fuses with RRF.
  ///
  /// Provide [keywordQuery] and/or [queryEmbedding]; omitted legs are skipped.
  Future<List<HybridSearchHit>> search({
    String? keywordQuery,
    List<double>? queryEmbedding,
    int limit = 20,
    int candidateLimit = 50,
  }) async {
    if (limit <= 0) return const [];

    final trimmedKeyword = keywordQuery?.trim() ?? '';
    final hasKeyword = trimmedKeyword.isNotEmpty;
    final hasVector = queryEmbedding != null &&
        queryEmbedding.length == localTranscriptEmbeddingDimensions;

    if (!hasKeyword && !hasVector) return const [];

    final keywordFuture = hasKeyword
        ? _runLexicalSearch(trimmedKeyword, candidateLimit)
        : Future<List<KeywordSearchHit>>.value(const []);
    final semanticFuture = hasVector
        ? _runSemanticSearch(queryEmbedding, candidateLimit)
        : Future<List<SemanticSearchHit>>.value(const []);

    final (keywordHits, semanticHits) = await (
      keywordFuture,
      semanticFuture,
    ).wait;

    return _merger.mergeAndRank(
      keywordHits: keywordHits,
      semanticHits: semanticHits,
      limit: limit,
    );
  }

  Future<List<KeywordSearchHit>> _runLexicalSearch(
    String query,
    int limit,
  ) async {
    final entryIds = await _lexicalSearch.keywordSearch(
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

  Future<List<SemanticSearchHit>> _runSemanticSearch(
    List<double> queryEmbedding,
    int limit,
  ) async {
    if (limit <= 0) return const [];

    final query = _embeddedNodeBox
        .query(
          EmbeddedNode_.embedding.nearestNeighborsF32(queryEmbedding, limit),
        )
        .build();

    try {
      final scored = query.findWithScores();
      return scored
          .asMap()
          .entries
          .map(
            (entry) => SemanticSearchHit(
              entryId: entry.value.object.entryId,
              rank: entry.key + 1,
              cosineSimilarity: _distanceToCosineSimilarity(entry.value.score),
            ),
          )
          .toList(growable: false);
    } finally {
      query.close();
    }
  }

  /// ObjectBox cosine distance is `1 - similarity` for normalized vectors.
  static double _distanceToCosineSimilarity(double distance) {
    return (1.0 - distance).clamp(0.0, 1.0);
  }
}
