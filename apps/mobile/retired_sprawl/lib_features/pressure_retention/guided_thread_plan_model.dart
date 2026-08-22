/// A lightweight "yesterday → today" plan built from the user's own thread
/// evidence: what was already covered, what is worth checking, and one small
/// next recording. A simple plan, never homework — and never fabricated.
class GuidedThreadPlan {
  const GuidedThreadPlan({
    required this.hasPlan,
    this.title = defaultTitle,
    this.basedOnLine = defaultBasedOnLine,
    this.alreadyCovered = const [],
    this.worthChecking = const [],
    this.nextPrompt = '',
    this.encouragementLine = defaultEncouragementLine,
    this.sourceTerms = const [],
    this.evidenceSnippets = const [],
    this.entryIds = const [],
  });

  factory GuidedThreadPlan.none() => const GuidedThreadPlan(hasPlan: false);

  /// A plan needs at least this many related entries behind it.
  static const int minRelatedEntries = 2;

  /// Caps keep the plan compact — a glance, not a workload.
  static const int maxTerms = 3;
  static const int maxSnippets = 2;
  static const int maxAlreadyCovered = 3;
  static const int maxWorthChecking = 3;

  static const String defaultTitle = 'Today\u2019s thread plan';
  static const String defaultBasedOnLine = 'Based on your recent archive';
  static const String defaultEncouragementLine =
      'You do not need to solve everything today.';

  static const String alreadyCoveredHeading = 'Already covered';
  static const String worthCheckingHeading = 'Worth checking';
  static const String nextRecordingHeading = 'One small next recording';
  static const String recordCtaLabel = 'Record this';

  /// False when the archive does not hold enough related evidence.
  final bool hasPlan;

  final String title;
  final String basedOnLine;

  /// What the user already named or logged — accomplishment, not tasks.
  final List<String> alreadyCovered;

  /// 1–3 short open items still worth a look today.
  final List<String> worthChecking;

  /// One clear prompt handed to the Record screen.
  final String nextPrompt;

  final String encouragementLine;

  /// Thread terms behind the plan (capped at [maxTerms]).
  final List<String> sourceTerms;

  /// The user's exact saved words (capped at [maxSnippets]). Never invented.
  final List<String> evidenceSnippets;

  /// Journal entry ids the plan is grounded in.
  final List<String> entryIds;
}