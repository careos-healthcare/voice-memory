import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';

/// Copy aligned with web [THEORY_PAGE] and [THEORY_FEEDBACK_LABELS].
abstract final class TheoryPageCopy {
  TheoryPageCopy._();

  static const eyebrow = 'Working theories';
  static const title = 'Theories your archive is testing';
  static const lead =
      'Falsifiable hypotheses from patterns in your saved reflections — not fixed labels.';
  static const disclaimer =
      'Not advice, not clinical labeling, and not a fixed identity label — only hypotheses tied to your saved reflections.';

  static const activeTitle = 'Active';
  static const strengtheningTitle = 'Strengthening';
  static const weakeningTitle = 'Weakening';
  static const resolvedTitle = 'Resolved';
  static const retiredTitle = 'Retired';
  static const whatChangedLabel = 'What changed?';
  static const supportingLabel = 'Supporting';
  static const contradictingLabel = 'Contradicting';
  static const confidenceLabel = 'Confidence';
  static const emptyTitle = 'No working theories yet';
  static const emptyBody =
      'After a few reflections, ArchiveMe can surface falsifiable hypotheses from patterns already in your archive.';
  static const loadingBody = 'Reading your thinking history…';
  static const showEvidence = 'Show evidence';
  static const hideEvidence = 'Hide evidence';
  static const yourRead = 'Your read';
  static const feedbackSaved = 'Saved — helps calibrate what feels useful.';

  static const Map<TheoryFeedbackReaction, String> feedbackLabels = {
    TheoryFeedbackReaction.feelsTrue: 'Feels true',
    TheoryFeedbackReaction.partlyTrue: 'Partly true',
    TheoryFeedbackReaction.notTrue: 'Not true',
    TheoryFeedbackReaction.tooObvious: 'Too obvious',
    TheoryFeedbackReaction.surprising: 'Surprising',
  };
}

abstract final class EvolvingViewCardCopy {
  EvolvingViewCardCopy._();

  static const headline = 'Your archive has started forming a view.';
  static const subline = 'Each new reflection can change that view.';
  static const totalTheories = 'Theories tracked';
  static const underReview = 'Under review';
  static const strengthening = 'Strengthening';
  static const weakeningResolved = 'Weakening or resolved';
  static const lastUpdated = 'Last updated';
}