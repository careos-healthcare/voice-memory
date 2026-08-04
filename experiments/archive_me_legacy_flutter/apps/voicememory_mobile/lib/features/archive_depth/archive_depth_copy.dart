import 'archive_depth_models.dart';
import '../pro_value/pro_value_copy.dart';

/// User-facing copy for the archive depth meter — no pressure or certainty.
abstract final class ArchiveDepthCopy {
  ArchiveDepthCopy._();

  static const cardTitle = 'Archive depth';
  static const proPreviewButton = ProValueCopy.proPreviewButton;
  static const proLineLongTerm = ProValueCopy.cardProLine;

  static const whyDepthTitle = 'Why archive depth matters';
  static const whyDepthBodyOne =
      'Your archive becomes more useful when ArchiveMe has more evidence to compare.';
  static const whyDepthBodyTwo =
      'Depth grows as you save usable moments — not from daily pressure or habit scores.';

  static const notStartedLabel = 'Archive not started yet';
  static const notStartedExplanation = 'Save one moment to begin.';

  static const firstEvidenceLabel = 'First evidence saved';
  static const firstEvidenceExplanation =
      'ArchiveMe has one moment. Add another when this shows up again.';

  static const startingToCompareLabel = 'Starting to compare';
  static const startingToCompareExplanation =
      'ArchiveMe can begin comparing moments.';

  static const cautiousBeliefLabel = 'Cautious belief forming';
  static const cautiousBeliefExplanation =
      'Your archive has enough evidence for a cautious belief.';

  static const weeklyReviewLabel = 'Weekly review ready';
  static const weeklyReviewExplanation =
      'ArchiveMe can now create a broader review.';

  static const longTermLabel = 'Long-term archive building';
  static const longTermExplanation =
      'This is where longer-term change history becomes more useful.';

  static const nextStepAddMoment =
      'Add one more moment when this pattern appears again.';
  static const nextStepTagUntagged =
      'Tag untagged moments to improve context evidence.';
  static const nextStepReviewChanges = 'Review what changed since last time.';

  static String progressLabel({
    required int savedCount,
    required int usableCount,
  }) {
    final savedWord = savedCount == 1 ? 'moment' : 'moments';
    final usableWord = usableCount == 1 ? 'moment' : 'moments';
    return '$savedCount saved $savedWord · $usableCount usable evidence $usableWord';
  }

  static Iterable<String> allVisibleCopy() sync* {
    yield cardTitle;
    yield proPreviewButton;
    yield proLineLongTerm;
    yield whyDepthTitle;
    yield whyDepthBodyOne;
    yield whyDepthBodyTwo;
    yield notStartedLabel;
    yield notStartedExplanation;
    yield firstEvidenceLabel;
    yield firstEvidenceExplanation;
    yield startingToCompareLabel;
    yield startingToCompareExplanation;
    yield cautiousBeliefLabel;
    yield cautiousBeliefExplanation;
    yield weeklyReviewLabel;
    yield weeklyReviewExplanation;
    yield longTermLabel;
    yield longTermExplanation;
    yield nextStepAddMoment;
    yield nextStepTagUntagged;
    yield nextStepReviewChanges;
    yield progressLabel(savedCount: 1, usableCount: 1);
  }

  static ({String label, String explanation}) levelCopy(
    ArchiveDepthLevel level,
  ) => switch (level) {
    ArchiveDepthLevel.notStarted => (
      label: notStartedLabel,
      explanation: notStartedExplanation,
    ),
    ArchiveDepthLevel.firstEvidence => (
      label: firstEvidenceLabel,
      explanation: firstEvidenceExplanation,
    ),
    ArchiveDepthLevel.startingToCompare => (
      label: startingToCompareLabel,
      explanation: startingToCompareExplanation,
    ),
    ArchiveDepthLevel.cautiousBelief => (
      label: cautiousBeliefLabel,
      explanation: cautiousBeliefExplanation,
    ),
    ArchiveDepthLevel.weeklyReviewReady => (
      label: weeklyReviewLabel,
      explanation: weeklyReviewExplanation,
    ),
    ArchiveDepthLevel.longTermBuilding => (
      label: longTermLabel,
      explanation: longTermExplanation,
    ),
  };
}
