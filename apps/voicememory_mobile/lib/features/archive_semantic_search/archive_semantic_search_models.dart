import 'dart:typed_data';

enum ArchiveSemanticSearchIntent {
  general,
  topicEnumeration,
  happiest,
  saddest,
  mostAnxious,
  calmest,
}

final class ArchiveSemanticSearchQuery {
  const ArchiveSemanticSearchQuery({
    required this.raw,
    required this.searchText,
    required this.intent,
    this.after,
    this.before,
    this.concepts = const [],
  });

  final String raw;
  final String searchText;
  final ArchiveSemanticSearchIntent intent;
  final DateTime? after;
  final DateTime? before;
  final List<String> concepts;

  String get explanation => switch (intent) {
    ArchiveSemanticSearchIntent.topicEnumeration =>
      'Showing grounded mentions for every requested topic.',
    ArchiveSemanticSearchIntent.happiest =>
      'Ranked by explicit mood, intensity, and joyful wording.',
    ArchiveSemanticSearchIntent.saddest =>
      'Ranked by explicit mood, intensity, and sad wording.',
    ArchiveSemanticSearchIntent.mostAnxious =>
      'Ranked by explicit mood, intensity, and anxious wording.',
    ArchiveSemanticSearchIntent.calmest =>
      'Ranked by explicit mood, intensity, and calm wording.',
    ArchiveSemanticSearchIntent.general =>
      'Combined local semantic and exact-word matches.',
  };
}

final class ArchiveSemanticSearchResult {
  const ArchiveSemanticSearchResult({
    required this.entryId,
    required this.date,
    required this.score,
    required this.reason,
    required this.snippet,
    required this.snippetStartUtf16,
    required this.snippetEndUtf16,
    required this.evidenceStartUtf16,
    required this.evidenceEndUtf16,
    this.evidenceSource = 'transcript',
    this.mood,
  });

  final String entryId;
  final DateTime date;
  final double score;
  final String reason;
  final String snippet;
  final int snippetStartUtf16;
  final int snippetEndUtf16;
  final int evidenceStartUtf16;
  final int evidenceEndUtf16;
  final String evidenceSource;
  final String? mood;

  int get highlightStartUtf16 => evidenceStartUtf16 - snippetStartUtf16;
  int get highlightEndUtf16 => evidenceEndUtf16 - snippetStartUtf16;
}

final class ArchiveSemanticSearchPage {
  const ArchiveSemanticSearchPage({
    required this.query,
    required this.results,
    required this.totalResults,
    required this.hasMore,
    this.insufficientReason,
  });

  final ArchiveSemanticSearchQuery query;
  final List<ArchiveSemanticSearchResult> results;
  final int totalResults;
  final bool hasMore;
  final String? insufficientReason;
}

final class SemanticIndexSnapshot {
  SemanticIndexSnapshot({
    required this.vectors,
    required this.revisions,
    required this.createdAtById,
  });

  final Map<String, Float32List> vectors;
  final Map<String, String> revisions;
  final Map<String, DateTime> createdAtById;
}
