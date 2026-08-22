import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/insight_engine/reciprocal_rank_fusion.dart';
import 'package:archiveme_mobile/features/search/semantic_vector_fusion.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';

/// On-device hybrid retrieval combining FTS5 BM25 and sqlite-vec cosine search
/// via Reciprocal Rank Fusion.
class HybridSearchEngine {
  HybridSearchEngine({
    required MemoryTranscriptSearchRepository repository,
    ImageAttachmentEmbeddingRepository? imageRepository,
    ReciprocalRankFusion? fusion,
    bool? vectorFusionEnabled,
  }) : _repository = repository,
       _imageRepository = imageRepository,
       _fusion = fusion ?? const ReciprocalRankFusion(),
       _vectorFusionEnabled = vectorFusionEnabled;

  final MemoryTranscriptSearchRepository _repository;
  final ImageAttachmentEmbeddingRepository? _imageRepository;
  final ReciprocalRankFusion _fusion;

  /// Null means "ask [SemanticVectorFusion]"; a value pins it for one engine.
  final bool? _vectorFusionEnabled;

  bool get _fuseVectorLeg => _vectorFusionEnabled ?? SemanticVectorFusion.enabled;

  /// Runs keyword + vector retrieval asynchronously and merges with RRF.
  ///
  /// Pass [keywordQuery] and/or [queryEmbedding]; omitted legs are skipped.
  /// When both are provided, results are fused; when only one is provided,
  /// that leg's ranking is returned unchanged.
  Future<List<HybridSearchHit>> search({
    String? keywordQuery,
    List<double>? queryEmbedding,
    int limit = 20,
    int candidateLimit = 50,
  }) async {
    if (limit <= 0) return const [];

    final trimmedKeyword = keywordQuery?.trim() ?? '';
    final hasKeyword = trimmedKeyword.isNotEmpty;
    final hasTranscriptVector = queryEmbedding != null &&
        queryEmbedding.length == localTranscriptEmbeddingDimensions;

    // Fusing a leg the encoder cannot rank meaningfully does not dilute the
    // keyword ranking, it reorders it — see [SemanticVectorFusion]. While the
    // leg is off, a query carrying both returns BM25 order untouched.
    if (hasKeyword && hasTranscriptVector && !_fuseVectorLeg) {
      final keywordIds = await _repository.keywordSearch(
        query: trimmedKeyword,
        limit: candidateLimit,
      );
      return _hitsFromSingleList(keywordIds, limit, keywordRank: true);
    }

    if (hasKeyword && hasTranscriptVector) {
      return _repository.hybridSearch(
        keywordQuery: trimmedKeyword,
        queryEmbedding: queryEmbedding,
        limit: limit,
        candidateLimit: candidateLimit,
        rrfK: _fusion.k,
      );
    }

    final keywordFuture = hasKeyword
        ? _repository.keywordSearch(query: trimmedKeyword, limit: candidateLimit)
        : Future<List<String>>.value(const []);
    final vectorFuture = () {
      if (queryEmbedding == null) return Future<List<String>>.value(const []);
      if (queryEmbedding.length == localTranscriptEmbeddingDimensions) {
        return _vectorSearch(
          queryEmbedding: queryEmbedding,
          limit: candidateLimit,
        );
      }
      final imageRepo = _imageRepository;
      if (imageRepo != null &&
          queryEmbedding.length == imageEmbeddingDimensions) {
        return imageRepo.vectorSearchByEntry(
          queryEmbedding: queryEmbedding,
          limit: candidateLimit,
        );
      }
      return Future<List<String>>.value(const []);
    }();

    final results = await Future.wait([keywordFuture, vectorFuture]);
    final keywordIds = results[0];
    final vectorIds = results[1];

    if (keywordIds.isEmpty && vectorIds.isEmpty) return const [];

    if (keywordIds.isNotEmpty && vectorIds.isEmpty) {
      return _hitsFromSingleList(keywordIds, limit, keywordRank: true);
    }
    if (vectorIds.isNotEmpty && keywordIds.isEmpty) {
      return _hitsFromSingleList(vectorIds, limit, vectorRank: true);
    }

    return _repository.hybridSearch(
      keywordQuery: trimmedKeyword,
      queryEmbedding: queryEmbedding!,
      limit: limit,
      candidateLimit: candidateLimit,
      rrfK: _fusion.k,
    );
  }

  Future<void> upsertEmbedding({
    required String entryId,
    required List<double> embedding,
  }) {
    return _repository.upsertEmbedding(entryId: entryId, embedding: embedding);
  }

  Future<void> deleteEmbedding(String entryId) {
    return _repository.deleteEmbedding(entryId);
  }

  Future<List<String>> _vectorSearch({
    required List<double> queryEmbedding,
    required int limit,
  }) async {
    final transcriptFuture = _repository.vectorSearch(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
    final imageRepo = _imageRepository;
    if (imageRepo == null ||
        queryEmbedding.length != imageEmbeddingDimensions) {
      return transcriptFuture;
    }

    final results = await Future.wait([
      transcriptFuture,
      imageRepo.vectorSearchByEntry(
        queryEmbedding: queryEmbedding,
        limit: limit,
      ),
    ]);

    final transcriptIds = results[0];
    final imageIds = results[1];
    if (transcriptIds.isEmpty) return imageIds;
    if (imageIds.isEmpty) return transcriptIds;
    return _fusion.fuse([transcriptIds, imageIds], limit: limit);
  }

  List<HybridSearchHit> _hitsFromSingleList(
    List<String> entryIds,
    int limit, {
    bool keywordRank = false,
    bool vectorRank = false,
  }) {
    return entryIds
        .take(limit)
        .toList(growable: false)
        .asMap()
        .entries
        .map(
          (entry) => HybridSearchHit(
            entryId: entry.value,
            score: 1 / (_fusion.k + entry.key + 1),
            keywordRank: keywordRank ? entry.key + 1 : null,
            vectorRank: vectorRank ? entry.key + 1 : null,
          ),
        )
        .toList(growable: false);
  }
}
