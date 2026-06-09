/// How tomorrow's check question is sharpened.
enum CompellingCheckType {
  beforeMoment,
  helpedMoment,
  heavierMoment,
  changedMoment,
  exactMoment,
  repeatMoment,
}

/// Consumer-visible tomorrow check with context for why it is useful.
class CompellingCheckQuestion {
  const CompellingCheckQuestion({
    required this.type,
    required this.question,
    required this.whyThisCheck,
    required this.exampleAnswer,
    required this.sharpnessLabel,
    this.source = 'engine',
  });

  final CompellingCheckType type;
  final String question;
  final String whyThisCheck;
  final String exampleAnswer;
  final String sharpnessLabel;
  final String source;
}

/// Chooser labels surfaced in first-session and post-save cards.
abstract final class CompellingCheckSharpness {
  CompellingCheckSharpness._();

  static const gentle = 'Gentle';
  static const direct = 'Direct';
  static const practical = 'Practical';
  static const mostSpecific = 'Most specific';

  static const all = [gentle, direct, practical, mostSpecific];
}
