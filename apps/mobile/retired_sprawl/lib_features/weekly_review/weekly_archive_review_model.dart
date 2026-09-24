/// Weekly review visibility and content state.
enum WeeklyArchiveReviewState { hidden, forming, full }

class WeeklyArchiveReviewSection {
  const WeeklyArchiveReviewSection({
    required this.label,
    required this.body,
    required this.isSupported,
    this.evidencePhrases = const [],
  });

  final String label;
  final String body;
  final bool isSupported;
  final List<String> evidencePhrases;
}

class WeeklyArchiveReviewResult {
  const WeeklyArchiveReviewResult({
    required this.state,
    required this.title,
    this.subtitle,
    this.formingBody,
    this.whatRepeated,
    this.whatChanged,
    this.whatHelped,
    this.whatToWatchNext,
  });

  final WeeklyArchiveReviewState state;
  final String title;
  final String? subtitle;
  final String? formingBody;
  final WeeklyArchiveReviewSection? whatRepeated;
  final WeeklyArchiveReviewSection? whatChanged;
  final WeeklyArchiveReviewSection? whatHelped;
  final WeeklyArchiveReviewSection? whatToWatchNext;

  bool get isVisible =>
      state == WeeklyArchiveReviewState.forming ||
      state == WeeklyArchiveReviewState.full;

  String? get compactTeaser {
    if (state != WeeklyArchiveReviewState.full) return null;
    final repeat = whatRepeated;
    if (repeat != null && repeat.isSupported) return repeat.body;
    final changed = whatChanged;
    if (changed != null && changed.isSupported) return changed.body;
    return null;
  }
}
