import '../activation/weekly_archive_review.dart';

/// Calm, non-clinical copy for archive clarity progress.
abstract final class ArchiveClarityCopy {
  ArchiveClarityCopy._();

  static const route = '/archive-clarity-progress';
  static const recordRoute = '/record';
  static const betaFeedbackRoute = '/beta-feedback';
  static const archiveHomeRoute = '/archive-belief';

  static const screenTitle = 'Archive clarity';
  static const cardLabel = 'Archive clarity';
  static const evidenceStrengthLabel = 'Evidence strength';
  static const nextUsefulMomentLabel = 'Next useful moment';

  static const viewClarityCta = 'View archive clarity';
  static const saveMomentCta = 'Save a moment';
  static const openBetaFeedbackCta = 'Open beta feedback';
  static const pickWatchThemeCta = 'Open archive home';
  static const openWeeklyReviewCta = 'Open weekly review';
  static const reviewArchiveCta = 'Review archive';

  static const supportSectionTitle = 'Archive clarity';
  static const supportSectionBody =
      'See how much useful evidence your local archive has and what would make it '
      'more useful next. Nothing is uploaded.';

  static const betaOutcomesLabel = 'Archive clarity stage';

  static const screenshotTitle = 'Archive clarity (sample)';
  static const screenshotBody =
      'ArchiveMe shows archive stage and evidence strength from saved moment counts. '
      'Example only — no private data.';

  static const stageStarting = 'Starting';
  static const stageComparisonForming = 'Comparison forming';
  static const stagePatternEmerging = 'Pattern emerging';
  static const stageEvidenceGrowing = 'Evidence growing';
  static const stageReviewReady = 'Review ready';

  static const startingBody =
      'Your archive is ready for its first useful moment.';
  static const comparisonBody =
      'ArchiveMe has started collecting comparison material.';
  static const patternBody = 'ArchiveMe can start checking what repeats.';
  static const evidenceBody =
      'Your archive has enough evidence to make early comparisons.';
  static const reviewBody = 'Your first archive review is ready.';

  static const startingNext =
      'Save one moment your future archive can compare.';
  static const comparisonNext =
      'Save one more moment so it can check what repeats.';
  static const patternNext =
      'Mark whether the archive showed anything useful.';
  static const evidenceNext = 'Add one moment around a watch theme.';
  static const reviewNext =
      'Review what repeated, what changed, and what to watch next.';

  static String evidenceStrengthValue({
    required int savedCount,
    required int usableCount,
    required int target,
  }) {
    if (usableCount > 0 && usableCount != savedCount) {
      return '$savedCount of $target moments · $usableCount usable';
    }
    return '$savedCount of $target moments';
  }

  static String weeklyReviewRoute({required bool weeklyReviewAvailable}) =>
      weeklyReviewAvailable
          ? WeeklyArchiveReviewNavigation.route
          : archiveHomeRoute;

  static String weeklyReviewCta({required bool weeklyReviewAvailable}) =>
      weeklyReviewAvailable ? openWeeklyReviewCta : reviewArchiveCta;

  static List<String> get allVisibleStrings => [
        screenTitle,
        cardLabel,
        evidenceStrengthLabel,
        nextUsefulMomentLabel,
        viewClarityCta,
        saveMomentCta,
        openBetaFeedbackCta,
        pickWatchThemeCta,
        openWeeklyReviewCta,
        reviewArchiveCta,
        supportSectionTitle,
        supportSectionBody,
        betaOutcomesLabel,
        screenshotTitle,
        screenshotBody,
        stageStarting,
        stageComparisonForming,
        stagePatternEmerging,
        stageEvidenceGrowing,
        stageReviewReady,
        startingBody,
        comparisonBody,
        patternBody,
        evidenceBody,
        reviewBody,
        startingNext,
        comparisonNext,
        patternNext,
        evidenceNext,
        reviewNext,
        evidenceStrengthValue(savedCount: 1, usableCount: 1, target: 7),
        evidenceStrengthValue(savedCount: 3, usableCount: 2, target: 7),
      ];
}
