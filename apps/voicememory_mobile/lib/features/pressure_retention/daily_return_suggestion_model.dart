/// One tappable "Worth checking today" row on the Record screen.
class DailyReturnSuggestion {
  const DailyReturnSuggestion({
    required this.id,
    required this.title,
    required this.prompt,
    required this.reason,
    this.sourceTerms = const [],
    this.evidenceSnippet,
  });

  /// Stable id for dedupe and tests.
  final String id;

  /// Short row title, e.g. "Deadline pressure".
  final String title;

  /// The recording prompt used when the row is tapped.
  final String prompt;

  /// One small line explaining why this is here — grounded, never asserting.
  final String reason;

  /// The user terms this suggestion was built from (may be empty).
  final List<String> sourceTerms;

  /// A short line of the user's own previous words (fear / stop-cost note),
  /// already trimmed and capped. Null when no safe snippet exists — the
  /// evidence line is simply omitted, never fabricated.
  final String? evidenceSnippet;
}

/// The full suggestion list shown above the Record prompt area.
class DailyReturnSuggestionSet {
  const DailyReturnSuggestionSet({
    required this.suggestions,
    required this.personalized,
    this.label = '',
  });

  static const DailyReturnSuggestionSet empty = DailyReturnSuggestionSet(
    suggestions: [],
    personalized: false,
  );

  static const String heading = 'Worth checking today';
  static const String subLabel = "Based on what you've recorded";
  static const String archiveNoticedReason =
      'Your archive noticed this might be worth revisiting.';
  static const String evidenceLabel = 'From your archive:';

  final List<DailyReturnSuggestion> suggestions;

  /// True when [suggestions] were built from the user's own entries.
  final bool personalized;

  /// Card heading; empty for the non-personalized empty set.
  final String label;

  bool get hasSuggestions => personalized && suggestions.isNotEmpty;
}
