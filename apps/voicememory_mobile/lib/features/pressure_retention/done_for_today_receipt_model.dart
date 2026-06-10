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

  /// False before a save succeeds; the receipt only exists after one.
  final bool hasReceipt;

  final String title;

  /// Sense of completion — today's recording is saved.
  final String completionLine;

  /// What was added to the archive (thread-specific when a thread exists).
  final String archiveLine;

  /// What ArchiveMe can check tomorrow plus one calm return reason.
  final String tomorrowLine;

  final String restLine;

  /// Thread terms behind the receipt (capped at [maxTerms]); empty for the
  /// generic archive variant.
  final List<String> sourceTerms;

  /// Journal entry ids behind the thread, when thread evidence backs it.
  final List<String> entryIds;

  factory DoneForTodayReceipt.none() =>
      const DoneForTodayReceipt(hasReceipt: false);
}
