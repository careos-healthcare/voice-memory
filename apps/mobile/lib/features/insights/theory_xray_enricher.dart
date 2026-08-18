import 'package:archiveme_mobile/features/insight_engine/hybrid_search_engine.dart';
import 'package:archiveme_mobile/features/insight_engine/hybrid_search_models.dart';
import 'package:archiveme_mobile/features/insights/theory_xray_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';

/// Enriches [TheoryRankingInspection] with hybrid search and vector scores.
class TheoryXRayEnricher {
  const TheoryXRayEnricher({
    this.hybridSearch,
    this.searchRepository,
  });

  final HybridSearchEngine? hybridSearch;
  final MemoryTranscriptSearchRepository? searchRepository;

  Future<TheoryRankingInspection> enrich({
    required TheoryRankingInspection inspection,
    required String theoryStatement,
    required List<JournalEntry> entries,
  }) async {
    final byId = {for (final entry in entries) entry.id: entry};
    final chunkById = {
      for (final chunk in inspection.retrievedChunks) chunk.entryId: chunk,
    };

    final hybridHits = await _hybridHits(theoryStatement);
    final vectorScores = await _vectorScores(
      theoryStatement: theoryStatement,
      supportingEntryIds: inspection.retrievedChunks
          .where((c) => c.role == TheoryRetrievalRole.supporting)
          .map((c) => c.entryId),
    );

    final merged = <TheoryRetrievalChunk>[];
    final seen = <String>{};

    for (final chunk in inspection.retrievedChunks) {
      seen.add(chunk.entryId);
      merged.add(
        _mergeChunk(
          chunk,
          hybridHits[chunk.entryId],
          vectorScores[chunk.entryId],
        ),
      );
    }

    for (final hit in hybridHits.values) {
      if (seen.contains(hit.entryId)) continue;
      final entry = byId[hit.entryId];
      if (entry == null) continue;
      seen.add(hit.entryId);
      merged.add(
        TheoryRetrievalChunk(
          entryId: hit.entryId,
          excerpt: _trimExcerpt(entry.transcript),
          role: TheoryRetrievalRole.hybrid,
          recordedAt: entry.createdAt,
          hybridScore: hit.score,
          keywordRank: hit.keywordRank,
          vectorRank: hit.vectorRank,
          vectorSimilarity: vectorScores[hit.entryId],
        ),
      );
    }

    merged.sort((a, b) {
      final aScore = a.hybridScore ?? a.vectorSimilarity ?? 0;
      final bScore = b.hybridScore ?? b.vectorSimilarity ?? 0;
      return bScore.compareTo(aScore);
    });

    return TheoryRankingInspection(
      confidenceBreakdown: inspection.confidenceBreakdown,
      rankBreakdown: inspection.rankBreakdown,
      retrievedChunks: merged,
      finalConfidencePercent: inspection.finalConfidencePercent,
      finalRankScore: inspection.finalRankScore,
    );
  }

  Future<Map<String, HybridSearchHit>> _hybridHits(String statement) async {
    final engine = hybridSearch;
    if (engine == null || statement.trim().isEmpty) return const {};

    final hits = await engine.search(
      keywordQuery: statement,
      limit: 12,
      candidateLimit: 24,
    );
    return {for (final hit in hits) hit.entryId: hit};
  }

  Future<Map<String, double>> _vectorScores({
    required String theoryStatement,
    required Iterable<String> supportingEntryIds,
  }) async {
    final repo = searchRepository;
    if (repo == null) return const {};

    final queryEmbedding = await _queryEmbedding(
      repo: repo,
      theoryStatement: theoryStatement,
      supportingEntryIds: supportingEntryIds,
    );
    if (queryEmbedding == null) return const {};

    final hits = await repo.vectorSearchWithScores(
      queryEmbedding: queryEmbedding,
      limit: 24,
    );
    return {for (final hit in hits) hit.entryId: hit.cosineSimilarity};
  }

  Future<List<double>?> _queryEmbedding({
    required MemoryTranscriptSearchRepository repo,
    required String theoryStatement,
    required Iterable<String> supportingEntryIds,
  }) async {
    final stored = await repo.loadEmbeddingsFor(supportingEntryIds);
    if (stored.isNotEmpty) {
      return _meanEmbedding(stored.values);
    }

    final keywordIds = await repo.keywordSearch(
      query: theoryStatement,
      limit: 3,
    );
    final keywordStored = await repo.loadEmbeddingsFor(keywordIds);
    if (keywordStored.isEmpty) return null;
    return _meanEmbedding(keywordStored.values);
  }

  List<double>? _meanEmbedding(Iterable<List<double>> embeddings) {
    final lists = embeddings.toList(growable: false);
    if (lists.isEmpty) return null;
    final dims = lists.first.length;
    if (dims == 0) return null;

    final mean = List<double>.filled(dims, 0);
    for (final embedding in lists) {
      final length = embedding.length < dims ? embedding.length : dims;
      for (var i = 0; i < length; i++) {
        mean[i] += embedding[i];
      }
    }
    final count = lists.length;
    for (var i = 0; i < dims; i++) {
      mean[i] /= count;
    }
    return mean;
  }

  TheoryRetrievalChunk _mergeChunk(
    TheoryRetrievalChunk chunk,
    HybridSearchHit? hybridHit,
    double? vectorSimilarity,
  ) {
    if (hybridHit == null && vectorSimilarity == null) return chunk;
    return chunk.copyWith(
      hybridScore: hybridHit?.score,
      keywordRank: hybridHit?.keywordRank,
      vectorRank: hybridHit?.vectorRank,
      vectorSimilarity: vectorSimilarity,
    );
  }

  String _trimExcerpt(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 160) return normalized;
    return '${normalized.substring(0, 157)}…';
  }
}
