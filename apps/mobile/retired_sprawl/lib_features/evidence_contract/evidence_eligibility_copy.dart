/// User-facing copy governed by [EvidenceEligibilityPolicy].
abstract final class EvidenceEligibilityCopy {
  EvidenceEligibilityCopy._();

  static const relatedMomentsTitle = 'These entries may be related';
  static const relatedMomentsBody =
      'Thoughtprint noticed similar wording across two recorded entries. '
      'This is not an established pattern yet.';

  static const possiblePatternTitle = 'Possible pattern';
  static const possiblePatternBody =
      'These entries may repeat a similar theme. Review the evidence '
      'before treating it as settled.';

  static const changeTitle = 'What may have changed';
  static const changeBody =
      'Your earlier and recent entries describe this differently. '
      'This does not prove improvement or causation.';

  static const feedbackFits = 'Fits';
  static const feedbackPartlyFits = 'Partly fits';
  static const feedbackNotForMe = 'Not for me';

  static const exportYourWordsLabel = 'Your words';
  static const exportSuggestionLabel = 'Thoughtprint suggestion';
  static const exportReviewStatusLabel = 'Review status';
}
