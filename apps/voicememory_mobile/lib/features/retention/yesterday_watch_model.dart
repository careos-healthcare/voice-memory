/// User choice on the yesterday-watch card.
enum YesterdayWatchAnswer { cameBack, notToday, different }

/// Yesterday-watch return loop card content.
class YesterdayWatch {
  const YesterdayWatch({
    required this.title,
    required this.body,
    required this.daysSinceLastEntry,
    this.watchingPhrase,
  });

  final String title;
  final String body;
  final int daysSinceLastEntry;

  /// Grounded phrase when quality gate allows — never logged to analytics.
  final String? watchingPhrase;

  bool get hasGroundedPhrase =>
      watchingPhrase != null && watchingPhrase!.trim().isNotEmpty;
}
