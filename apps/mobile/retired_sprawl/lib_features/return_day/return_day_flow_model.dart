/// User choice on the return-day flow card.
enum ReturnDayFlowAnswer { cameBack, notToday, different }

/// Return Day Flow v2 card content.
class ReturnDayFlow {
  const ReturnDayFlow({
    required this.title,
    required this.body,
    required this.daysSinceLastEntry,
    this.watchingPhrase,
    this.source = 'journal_grounded',
    this.daysSinceSet = 0,
  });

  final String title;
  final String body;
  final int daysSinceLastEntry;

  /// Grounded phrase when quality gate allows — never logged to analytics.
  final String? watchingPhrase;
  final String source;
  final int daysSinceSet;

  bool get hasGroundedPhrase =>
      watchingPhrase != null && watchingPhrase!.trim().isNotEmpty;
}