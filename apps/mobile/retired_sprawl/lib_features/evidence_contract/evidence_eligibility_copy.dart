/// User-facing copy governed by [EvidenceEligibilityPolicy].
abstract final class EvidenceEligibilityCopy {
  EvidenceEligibilityCopy._();

  static const relatedMomentsTitle = 'These moments may be related';
  static const relatedMomentsBody =
      'ArchiveMe noticed similar wording across two saved moments. '
      'This is not an established pattern yet.';

  static const possiblePatternTitle = 'Possible pattern';
  static const possiblePatternBody =
      'These moments may repeat a similar theme. Review the evidence '
      'before treating it as settled.';

  static const changeTitle = 'What may have changed';
  static const changeBody =
      'Your earlier and recent moments describe this differently. '
      'This does not prove improvement or causation.';

  static const feedbackFits = 'Fits';
  static const feedbackPartlyFits = 'Partly fits';
  static const feedbackNotForMe = 'Not for me';

  static const exportYourWordsLabel = 'Your words';
  static const exportSuggestionLabel = 'ArchiveMe suggestion';
  static const exportReviewStatusLabel = 'Review status';
}
