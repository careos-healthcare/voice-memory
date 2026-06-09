/// How useful a reflection is for finding a pattern.
enum InputQualityLevel {
  strong,
  usable,
  vague,
  tooShort,
}

/// A specific reason a reflection is hard to turn into a pattern.
enum InputQualityIssue {
  tooShort,
  tooGeneral,
  noMoment,
  noFeelingOrAction,
  unclearReference,
  onlyMood,
  onlySummary,
}

/// The assessed quality of a single reflection, with coaching toward one
/// concrete moment.
class InputQualityResult {
  const InputQualityResult({
    required this.level,
    required this.issues,
    required this.score,
    required this.helpfulPrompt,
    required this.exampleRewrite,
    required this.shouldAskForSharpening,
  });

  final InputQualityLevel level;
  final List<InputQualityIssue> issues;

  /// 0..1 — higher is a clearer, more concrete moment.
  final double score;

  /// One short nudge toward a clearer moment.
  final String helpfulPrompt;

  /// A concrete example of what a useful moment sounds like.
  final String exampleRewrite;

  /// True for vague or too-short input, where coaching helps.
  final bool shouldAskForSharpening;
}
