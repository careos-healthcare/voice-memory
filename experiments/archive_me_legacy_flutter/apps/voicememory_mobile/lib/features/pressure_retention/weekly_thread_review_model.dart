/// Compact weekly review of what moved across the user's archive: what
/// returned, what may be fading, what changed, what evidence was added, and
/// one calm thing to look at next week.
///
/// Built only from real saved entries and the existing thread/belief
/// evidence — change is never fabricated, and lines that cannot be supported
/// are simply omitted. No streaks, no homework, no obligation.
class WeeklyThreadReview {
  const WeeklyThreadReview({
    required this.hasReview,
    this.title = '',
    this.weekSummaryLine = '',
    this.takeawayLine = '',
    this.returnedLine = '',
    this.fadedLine = '',
    this.changedLine = '',
    this.evidenceLine = '',
    this.nextWeekLine = '',
    this.sourceTerms = const [],
    this.evidenceSnippets = const [],
    this.entryIds = const [],
  });

  /// A review needs this many entries overall, or a connected thread
  /// (2+ related entries), before anything is shown.
  static const int minEntries = 3;

  /// The review window in days.
  static const int windowDays = 7;

  /// Caps keep the card compact and honest — top evidence only.
  static const int maxSnippets = 3;
  static const int maxTerms = 3;

  static const String defaultTitle = 'This week in your archive';

  static const String defaultWeekSummaryLine =
      'What returned, faded, or changed across your last 7 days.';

  /// One calm thing to look at next week — an observation to make, never an
  /// assignment to complete.
  static const String defaultNextWeekLine =
      'Next week, check whether this returned, faded, or changed.';

  static const String evidenceHeading = 'From your recordings';

  // Main takeaway variants — fixed copy only, chosen from which supported
  // lines exist. Cautious by design ("may be", "something shifted"); never
  // raw notes, belief phrases, snippets, or private terms.
  static const String returnedTakeaway =
      'Main takeaway: this thread came back this week.';
  static const String fadingTakeaway =
      'Main takeaway: this thread may be getting quieter.';
  static const String changedTakeaway =
      'Main takeaway: something shifted in the archive.';
  static const String evidenceOnlyTakeaway =
      'Main takeaway: your archive has more to compare now.';

  /// False when the archive holds too little evidence, or nothing moved
  /// this week — an empty review is never padded with filler claims.
  final bool hasReview;

  final String title;

  final String weekSummaryLine;

  /// The one-line sharpened summary of what moved this week. Always one of
  /// the fixed takeaway variants above — never user text, never fabricated
  /// when no line supports it.
  final String takeawayLine;

  /// e.g. "The work thread returned 2 times." Empty when the thread did not
  /// return inside the window.
  final String returnedLine;

  /// e.g. "The work thread appeared less often recently." Empty unless
  /// fading is genuinely detected.
  final String fadedLine;

  /// e.g. "One belief-like phrase showed up again." Empty unless a real
  /// change signal exists.
  final String changedLine;

  /// e.g. "You added 4 pieces of evidence." Empty when nothing was added
  /// inside the window.
  final String evidenceLine;

  final String nextWeekLine;

  /// Repeated terms behind the review (capped at [maxTerms]).
  final List<String> sourceTerms;

  /// The user's exact saved words (capped at [maxSnippets]). Never rewritten.
  final List<String> evidenceSnippets;

  /// The exact entries behind the review.
  final List<String> entryIds;

  factory WeeklyThreadReview.none() =>
      const WeeklyThreadReview(hasReview: false);
}
