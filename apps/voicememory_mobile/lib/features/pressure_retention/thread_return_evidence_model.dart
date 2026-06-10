/// How a detected thread is moving over time. Labels stay hedged — the app
/// reports what repeated, never a diagnosis or a certainty.
enum ThreadReturnStatus {
  returned(label: 'Returned'),
  fading(label: 'May be fading'),
  building(label: 'Building'),
  earlySignal(label: 'Early signal');

  const ThreadReturnStatus({required this.label});

  /// Consumer-facing chip label.
  final String label;
}

/// Evidence-backed continuity for one repeated thread in the user's archive:
/// what returned, how often, over how many days, and the exact recordings
/// behind it. Built only from real saved entries — never fabricated.
class ThreadReturnEvidence {
  const ThreadReturnEvidence({
    required this.hasEvidence,
    this.headline = '',
    this.summaryLine = '',
    this.status = ThreadReturnStatus.earlySignal,
    this.occurrenceCount = 0,
    this.daysWindow = 0,
    this.sourceTerms = const [],
    this.evidenceSnippets = const [],
    this.entryIds = const [],
    this.confidenceLabel = '',
  });

  /// A thread needs at least this many occurrences before anything is shown.
  static const int minOccurrences = 2;

  /// Stronger language ("returned", "building") needs at least this many.
  static const int minOccurrencesForStrongLanguage = 3;

  /// Caps keep the card compact and honest — top evidence only.
  static const int maxSnippets = 3;
  static const int maxTerms = 3;

  // Headlines per status — cautious, no certainty.
  static const String returnedTodayHeadline = 'This thread returned today';
  static const String returnedHeadline = 'This thread came back recently';
  static const String fadingHeadline = 'This pattern may be fading';
  static const String buildingHeadline = 'This thread may be building';
  static const String earlySignalHeadline = 'An early thread signal';

  // Count-based confidence labels — hedged, never certain.
  static const String earlySignalConfidence = 'Early signal';
  static const String repeatedSignalConfidence = 'Repeated signal';
  static const String strongRepeatedSignalConfidence = 'Strong repeated signal';

  static const String evidenceHeading = 'Evidence behind this';
  static const String basedOnLine = 'Based on your recent archive';

  /// False when the archive does not hold enough repeated evidence.
  final bool hasEvidence;

  final String headline;

  /// One grounded sentence, e.g. "Work pressure has appeared 3 times in
  /// 8 days."
  final String summaryLine;

  final ThreadReturnStatus status;

  /// Consumer-facing status chip text.
  String get statusLabel => status.label;

  /// How many saved entries the thread appeared in.
  final int occurrenceCount;

  /// Days spanned from the first to the latest occurrence (inclusive).
  final int daysWindow;

  /// Repeated terms behind the thread (capped at [maxTerms]).
  final List<String> sourceTerms;

  /// The user's exact words from the entries behind this thread (capped at
  /// [maxSnippets]). Empty when the entries hold no free-text notes.
  final List<String> evidenceSnippets;

  /// Journal entry ids behind the thread — the exact recordings.
  final List<String> entryIds;

  final String confidenceLabel;

  factory ThreadReturnEvidence.none() =>
      const ThreadReturnEvidence(hasEvidence: false);
}
