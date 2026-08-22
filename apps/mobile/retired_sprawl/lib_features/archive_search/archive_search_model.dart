import 'package:archiveme_mobile/features/archive_search/archive_search_parser.dart';

/// Constrained search intents — not open-ended chat.
enum ArchiveSearchIntent {
  lastSeen,
  helpedBefore,
  momentsAbout,
  feltLighter,
  feltHeavier,
  changed,
  thisWeek,
  freeText,
}

/// A parsed, local search request.
class ArchiveSearchQuery {
  const ArchiveSearchQuery({
    required this.intent,
    this.rawText = '',
    this.normalizedTerm,
  });

  factory ArchiveSearchQuery.fromText(String text) =>
      parseArchiveSearchQuery(text);

  final ArchiveSearchIntent intent;
  final String rawText;

  /// Optional topic term (e.g. work, family) for [ArchiveSearchIntent.momentsAbout].
  final String? normalizedTerm;
}

/// One matching row in Ask my Archive results.
class ArchiveSearchResult {
  const ArchiveSearchResult({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    this.momentId,
    this.patternTitle,
    this.resultHint,
    this.tags = const [],
    this.nextCheck,
  });

  final String id;
  final String title;
  final String body;
  final DateTime date;
  final String? momentId;
  final String? patternTitle;
  final String? resultHint;
  final List<String> tags;
  final String? nextCheck;
}

/// Guided chip shown on the Ask my Archive screen.
class ArchiveSuggestedSearch {
  const ArchiveSuggestedSearch(this.label, this.query);

  final String label;
  final ArchiveSearchQuery query;
}

const List<ArchiveSuggestedSearch> kArchiveSuggestedSearches = [
  ArchiveSuggestedSearch(
    'When did this last show up?',
    ArchiveSearchQuery(intent: ArchiveSearchIntent.lastSeen),
  ),
  ArchiveSuggestedSearch(
    'What helped before?',
    ArchiveSearchQuery(intent: ArchiveSearchIntent.helpedBefore),
  ),
  ArchiveSuggestedSearch(
    'Show moments about work',
    ArchiveSearchQuery(
      intent: ArchiveSearchIntent.momentsAbout,
      normalizedTerm: 'work',
    ),
  ),
  ArchiveSuggestedSearch(
    'When did it feel lighter?',
    ArchiveSearchQuery(intent: ArchiveSearchIntent.feltLighter),
  ),
  ArchiveSuggestedSearch(
    'What changed this week?',
    ArchiveSearchQuery(
      intent: ArchiveSearchIntent.changed,
      rawText: 'What changed this week?',
    ),
  ),
];