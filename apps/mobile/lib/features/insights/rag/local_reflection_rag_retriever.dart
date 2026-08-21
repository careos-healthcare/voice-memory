import 'package:archiveme_mobile/features/insights/rag/routine_rag_models.dart';
import 'package:archiveme_mobile/features/search/offline_reflection_vector_search_service.dart';
import 'package:archiveme_mobile/features/theme_tracking/theme_tracker_service.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_repository.dart';

/// Retrieves past reflections from the drift-backed SQLite mirror for RAG.
class LocalReflectionRagRetriever {
  LocalReflectionRagRetriever({
    required JournalSqliteRepository journalRepository,
    required OfflineReflectionVectorSearchService vectorSearch,
  }) : _journalRepository = journalRepository,
       _vectorSearch = vectorSearch;

  final JournalSqliteRepository _journalRepository;
  final OfflineReflectionVectorSearchService _vectorSearch;

  Future<List<RagContextChunk>> retrieve({
    required RoutineRagQuery query,
    List<JournalEntry>? localEntries,
  }) async {
    final entries = localEntries ?? await _journalRepository.fetchAllActive();
    if (entries.isEmpty) return const [];

    final themeFiltered = _filterByThemesAndMood(
      entries: entries,
      mood: query.currentMood,
      themes: query.recurringThemes,
    );

    final semanticScores = await _semanticScores(query);
    final ranked = _rankChunks(
      entries: entries,
      preferred: themeFiltered,
      semanticScores: semanticScores,
      query: query,
    );

    return ranked.take(query.maxChunks).toList(growable: false);
  }

  Future<Map<String, double>> _semanticScores(RoutineRagQuery query) async {
    final semanticQuery = query.semanticQuery?.trim();
    if (semanticQuery == null || semanticQuery.isEmpty) return const {};

    try {
      final hits = await _vectorSearch.searchSimilarText(
        query: semanticQuery,
        limit: query.maxChunks * 2,
      );
      return {
        for (final hit in hits) hit.entryId: hit.cosineSimilarity,
      };
    } on Object {
      return const {};
    }
  }

  List<JournalEntry> _filterByThemesAndMood({
    required List<JournalEntry> entries,
    required String? mood,
    required List<String> themes,
  }) {
    final normalizedThemes = themes
        .map((theme) => theme.trim().toLowerCase())
        .where((theme) => theme.isNotEmpty)
        .toSet();
    final normalizedMood = mood?.trim().toLowerCase();

    return entries.where((entry) {
      if (normalizedMood != null &&
          normalizedMood.isNotEmpty &&
          entry.reflection.mood.toLowerCase() == normalizedMood) {
        return true;
      }
      if (normalizedThemes.isEmpty) return false;
      final entryThemes = ThemeTrackerService.themesForEntry(entry);
      if (entryThemes.intersection(normalizedThemes).isNotEmpty) return true;
      for (final theme in entry.reflection.recurringThemes) {
        if (normalizedThemes.contains(theme.trim().toLowerCase())) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
  }

  List<RagContextChunk> _rankChunks({
    required List<JournalEntry> entries,
    required List<JournalEntry> preferred,
    required Map<String, double> semanticScores,
    required RoutineRagQuery query,
  }) {
    final byId = {for (final entry in entries) entry.id: entry};
    final scores = <String, double>{};

    for (var i = 0; i < preferred.length; i++) {
      scores[preferred[i].id] = (scores[preferred[i].id] ?? 0) + (1 - i * 0.05);
    }

    for (final entry in semanticScores.entries) {
      scores[entry.key] = (scores[entry.key] ?? 0) + entry.value;
    }

    if (query.emotionalIntensity != null) {
      for (final entry in entries) {
        final delta = (entry.reflection.emotionalIntensity -
                query.emotionalIntensity!)
            .abs();
        if (delta <= 2) {
          scores[entry.id] = (scores[entry.id] ?? 0) + 0.35;
        }
      }
    }

    final rankedIds = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final chunks = <RagContextChunk>[];
    for (final scored in rankedIds) {
      final entry = byId[scored.key];
      if (entry == null) continue;
      chunks.add(_chunkFromEntry(entry, scored.value));
    }

    if (chunks.isNotEmpty) return chunks;

    final fallback = List<JournalEntry>.from(entries)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return fallback
        .take(query.maxChunks)
        .map((entry) => _chunkFromEntry(entry, 0.25))
        .toList(growable: false);
  }

  RagContextChunk _chunkFromEntry(JournalEntry entry, double score) {
    final reflection = entry.reflection;
    return RagContextChunk(
      entryId: entry.id,
      createdAt: entry.createdAt,
      mood: reflection.mood,
      themes: reflection.recurringThemes,
      summary: _summaryFor(entry),
      relevanceScore: score,
      tensionOrContradiction: reflection.tensionOrContradiction,
      nextSmallAction: reflection.nextSmallAction,
    );
  }

  static String _summaryFor(JournalEntry entry) {
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
    if (joined.length <= 180) return joined;
    return '${joined.substring(0, 177).trim()}…';
  }
}
