/// One labeled reflection for first-pattern QA.
class FirstPatternQualitySample {
  const FirstPatternQualitySample({
    required this.id,
    required this.reflectionText,
    required this.expectedCategory,
    required this.acceptableTitles,
    this.unacceptableTitles = const [],
    this.notes,
    this.qaTags = const [],
  });

  final String id;
  final String reflectionText;
  final String expectedCategory;
  final List<String> acceptableTitles;
  final List<String> unacceptableTitles;
  final String? notes;

  /// Harness tags: `vague`, `neutral`, `negation`, `ambiguous`, `positive`, `multi`.
  final List<String> qaTags;

  bool get isVagueOrNeutral =>
      qaTags.contains('vague') || qaTags.contains('neutral');

  bool get isNegation => qaTags.contains('negation');

  bool get isAmbiguous => qaTags.contains('ambiguous');

  bool get isPositive => qaTags.contains('positive');
}
