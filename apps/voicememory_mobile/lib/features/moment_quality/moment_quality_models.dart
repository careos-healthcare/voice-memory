/// Local quality band for moment draft/saved text — not a score.
enum MomentQualityLevel {
  veryShort,
  someDetail,
  strongDetail,
}

/// Deterministic coach output from [MomentQualityEngine].
class MomentQualityResult {
  const MomentQualityResult({
    required this.level,
    required this.title,
    required this.body,
    this.suggestions = const [],
  });

  final MomentQualityLevel level;
  final String title;
  final String body;
  final List<String> suggestions;

  bool get isVisible => title.isNotEmpty;
}
