/// Consumer-visible retention loop state for tomorrow's check.
enum RetentionStateType {
  noCheckSet,
  checkSetForTomorrow,
  checkDueToday,
  checkMissed,
  loopClosed,
  nextCheckChosen,
}

/// One retention status surfaced on Record and Patterns.
class RetentionState {
  const RetentionState({
    required this.type,
    required this.title,
    required this.body,
    required this.primaryCtaLabel,
    this.checkQuestion,
    this.patternTitle,
    this.targetDate,
    this.secondaryCtaLabel,
    this.urgencyLabel,
    this.compact = false,
  });

  final RetentionStateType type;
  final String title;
  final String body;
  final String? checkQuestion;
  final String? patternTitle;
  final String? targetDate;
  final String primaryCtaLabel;
  final String? secondaryCtaLabel;
  final String? urgencyLabel;
  final bool compact;
}
