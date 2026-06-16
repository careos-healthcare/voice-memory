/// Post-save closure: today's recording is complete, here is what it added,
/// and here is the one calm reason to come back tomorrow. Closure, not
/// another action — and never homework.
class DoneForTodayReceipt {
  const DoneForTodayReceipt({
    required this.hasReceipt,
    this.title = defaultTitle,
    this.completionLine = '',
    this.archiveLine = '',
    this.tomorrowLine = '',
    this.restLine = defaultRestLine,
    this.tomorrowCueTitle = '',
    this.tomorrowCueLine = '',
    this.sourceTerms = const [],
    this.entryIds = const [],
  });

  /// Keeps the receipt grounded — at most a hint of the thread behind it.
  static const int maxTerms = 3;

  static const String defaultTitle = 'Done for today';
  static const String defaultRestLine =
      'You do not need to keep working on this now.';

  /// Optional CTA into the existing Patterns / thread plan surface.
  static const String viewThreadPlanLabel = 'View thread plan';

  /// One concrete thing to check tomorrow — an option, never an obligation.
  static const String defaultTomorrowCueTitle = 'Tomorrow, check one thing';

  /// Autonomy line under the cue: returning stays the user's choice.
  static const String tomorrowCueAutonomyLine =
      'Only if it still feels worth checking.';

  /// Cue fallback when no thread or term exists.
  static const String genericTomorrowCue = 'See whether this shows up again.';

  /// False before a save succeeds; the receipt only exists after one.
  final bool hasReceipt;

  final String title;

  /// Sense of completion — that is enough for today.
  final String completionLine;

  /// What was added to the archive (thread-specific when a thread exists).
  final String archiveLine;

  /// One concrete return reason: what ArchiveMe can check tomorrow.
  final String tomorrowLine;

  final String restLine;

  /// Heading for the concrete tomorrow cue, e.g. "Tomorrow, check one thing".
  final String tomorrowCueTitle;

  /// One concrete sentence to check tomorrow, shaped by the thread status,
  /// e.g. "See whether the work thread stays quieter."
  final String tomorrowCueLine;

  /// Thread terms behind the receipt (capped at [maxTerms]); empty for the
  /// generic archive variant.
  final List<String> sourceTerms;

  /// Journal entry ids behind the thread, when thread evidence backs it.
  final List<String> entryIds;

  factory DoneForTodayReceipt.none() =>
      const DoneForTodayReceipt(hasReceipt: false);
}
