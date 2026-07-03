/// Adaptive daily question state derived from archive metadata.
enum AdaptiveDailyQuestionKind {
  noEntries,
  oneEntry,
  twoNoClearMatch,
  twoRelated,
  confirmedRepeat,
  returnSofter,
  returnStronger,
  returnSame,
  patternChanged,
  helpfulActionAppeared,
}

/// One adaptive question for today's one question surfaces.
class AdaptiveDailyQuestionResult {
  const AdaptiveDailyQuestionResult({
    required this.kind,
    required this.questionText,
    required this.helperText,
    this.usesPhrase = false,
  });

  final AdaptiveDailyQuestionKind kind;
  final String questionText;
  final String helperText;
  final bool usesPhrase;
}
