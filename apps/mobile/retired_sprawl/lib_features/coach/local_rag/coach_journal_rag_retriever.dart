import 'package:archiveme_mobile/features/coach/local_rag/coach_rag_models.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Retrieves journal excerpts via local SQLite reflection + transcript vectors.
abstract interface class CoachRagRetriever {
  Future<List<CoachRagContextChunk>> retrieve({
    required CoachRagQuery query,
    List<JournalEntry>? localEntries,
  });
}

class CoachJournalRagRetriever implements CoachRagRetriever {
  CoachJournalRagRetriever({
    required JournalSqliteRepository journalRepository,
    required OfflineReflectionVectorSearchService reflectionVectorSearch,
  }) : _journalRepository = journalRepository,
       _reflectionVectorSearch = reflectionVectorSearch;

  final JournalSqliteRepository _journalRepository;
  final OfflineReflectionVectorSearchService _reflectionVectorSearch;

  Future<List<CoachRagContextChunk>> retrieve({
    required CoachRagQuery query,
    List<JournalEntry>? localEntries,
  }) async {
    final retrievalText = query.combinedRetrievalText;
    if (retrievalText.length < 4) return const [];

    final entries = localEntries ?? await _journalRepository.fetchAllActive();
    if (entries.isEmpty) return const [];

    final byId = {for (final entry in entries) entry.id: entry};
    final scores = <String, double>{};
    final sources = <String, CoachRagChunkSource>{};

    await _mergeReflectionHits(
      retrievalText: retrievalText,
      limit: query.maxChunks * 2,
      scores: scores,
      sources: sources,
    );
    await _mergeTranscriptHits(
      retrievalText: retrievalText,
      limit: query.maxChunks * 2,
      scores: scores,
      sources: sources,
    );

    if (scores.isEmpty) {
      return _recentFallback(entries, query.maxChunks);
    }

    final ranked = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chunks = <CoachRagContextChunk>[];
    for (final scored in ranked) {
      final entry = byId[scored.key];
      if (entry == null) continue;
      chunks.add(
        _chunkFromEntry(
          entry,
          score: scored.value,
          source: sources[scored.key] ?? CoachRagChunkSource.reflectionEmbedding,
        ),
      );
      if (chunks.length >= query.maxChunks) break;
    }

    return chunks.isNotEmpty
        ? chunks
        : _recentFallback(entries, query.maxChunks);
  }

  Future<void> _mergeReflectionHits({
    required String retrievalText,
    required int limit,
    required Map<String, double> scores,
    required Map<String, CoachRagChunkSource> sources,
  }) async {
    try {
      final hits = await _reflectionVectorSearch.searchSimilarText(
        query: retrievalText,
        limit: limit,
      );
      for (final hit in hits) {
        scores[hit.entryId] = (scores[hit.entryId] ?? 0) + hit.cosineSimilarity;
        sources.putIfAbsent(
          hit.entryId,
          () => CoachRagChunkSource.reflectionEmbedding,
        );
      }
    } on Object {
      return;
    }
  }

  Future<void> _mergeTranscriptHits({
    required String retrievalText,
    required int limit,
    required Map<String, double> scores,
    required Map<String, CoachRagChunkSource> sources,
  }) async {
    try {
      final queryEmbedding = await _reflectionVectorSearch.embedText(
        retrievalText,
      );
      final entryIds = await _journalRepository.vectorSearchTranscripts(
        queryEmbedding: queryEmbedding,
        limit: limit,
      );
      for (var i = 0; i < entryIds.length; i++) {
        final entryId = entryIds[i];
        final rankBoost = 1 - (i * 0.04);
        scores[entryId] = (scores[entryId] ?? 0) + (0.55 * rankBoost);
        sources.putIfAbsent(entryId, () => CoachRagChunkSource.transcriptEmbedding);
      }
    } on Object {
      return;
    }
  }

  List<CoachRagContextChunk> _recentFallback(
    List<JournalEntry> entries,
    int maxChunks,
  ) {
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted
        .take(maxChunks)
        .map(
          (entry) => _chunkFromEntry(
            entry,
            score: 0.2,
            source: CoachRagChunkSource.recentFallback,
          ),
        )
        .toList(growable: false);
  }

  CoachRagContextChunk _chunkFromEntry(
    JournalEntry entry, {
    required double score,
    required CoachRagChunkSource source,
  }) {
    return CoachRagContextChunk(
      entryId: entry.id,
      createdAt: entry.createdAt,
      excerpt: _excerptFor(entry),
      relevanceScore: score,
      mood: entry.reflection.mood,
      themes: entry.reflection.recurringThemes,
      source: source,
    );
  }

  static String _excerptFor(JournalEntry entry) {
    final reflection = entry.reflection;
    final parts = <String>[
      if (reflection.concreteObservation.trim().isNotEmpty)
        reflection.concreteObservation.trim(),
      if (reflection.exactLanguagePattern.trim().isNotEmpty)
        reflection.exactLanguagePattern.trim(),
      if ((reflection.tensionOrContradiction ?? '').trim().isNotEmpty)
        reflection.tensionOrContradiction!.trim(),
      if (entry.transcript.trim().isNotEmpty) entry.transcript.trim(),
    ];
    final joined = parts.join(' · ');
    if (joined.length <= 220) return joined;
    return '${joined.substring(0, 217).trim()}…';
  }
}
