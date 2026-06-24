import '../activation/weekly_archive_review.dart';

/// Calm, evidence-based copy for the first-week return path.
abstract final class FirstWeekPathCopy {
  FirstWeekPathCopy._();

  static const route = '/first-week-path';
  static const recordRoute = '/record';
  static const betaFeedbackRoute = '/beta-feedback';
  static const archiveHomeRoute = '/archive-belief';

  static const screenTitle = 'First week path';
  static const cardLabel = 'First week path';

  static const startTitle = 'Start your first week';
  static const startBody =
      'Save seven moments over your first week to build a useful archive loop with ArchiveMe.';
  static const saveFirstMomentCta = 'Save first moment';
  static const saveMomentCta = 'Save a moment';
  static const openBetaFeedbackCta = 'Open beta feedback';
  static const pickWatchThemeCta = 'Pick a watch theme';
  static const addThemeMomentCta = 'Add a themed moment';
  static const reviewChangesCta = 'Review what changed';
  static const openWeeklyReviewCta = 'Open weekly review';
  static const reviewArchiveCta = 'Review archive';
  static const openPathCta = 'Open first week path';
  static const viewFullPathCta = 'View full path';

  static const completeTitle = 'First week path complete';
  static const completeBody =
      'You saved enough moments for your first weekly archive review.';

  static const screenshotCardTitle = 'First week path (sample)';
  static const screenshotCardBody =
      'ArchiveMe guides early users from a first saved moment through comparison, '
      'watch themes, and a first weekly review. Example only — no private data.';

  static const supportSectionTitle = 'First week path';
  static const supportSectionBody =
      'Follow the guided first-week path from your first saved moment through your '
      'first weekly archive review. Local only — nothing is uploaded.';

  static const helpSectionTitle = 'Guided first-week path';
  static const helpSectionBullet =
      'Open First week path for the guided beta route from first saved moment to first weekly review.';

  static const betaOutcomesLabel = 'First week path progress';

  static String progressLabel(int completed, int total) =>
      'Step $completed of $total complete';

  static String progressLabelStart(int total) => 'Step 0 of $total complete';

  static const day1Reward = 'Your archive has started.';
  static const day1Next =
      'Come back with one more moment so ArchiveMe can compare.';

  static const day2Reward = 'ArchiveMe now has comparison material.';
  static const day2Next =
      'Save one more moment to see whether anything repeats.';

  static const day3Reward = 'ArchiveMe can start checking what repeats.';
  static const day3Next =
      'Open beta feedback and mark whether this was useful.';

  static const day4Reward = 'You can see what to watch next.';
  static const day4Next = 'Add one moment around that theme.';

  static const day5Reward = 'Your evidence is getting stronger.';
  static const day5Next = 'Review what changed.';

  static const day6Reward =
      'You can now compare this moment with earlier ones.';
  static const day6Next = 'Review what changed in your archive.';

  static const day7Reward = 'This is your first weekly archive review.';
  static const day7Next = 'Open your weekly archive review when you are ready.';

  static const day1Job = 'Save your first moment';
  static const day2Job = 'Save a second moment';
  static const day3Job = 'Save a third moment';
  static const day4Job = 'Pick or confirm a watch theme';
  static const day5Job = 'Add more evidence around your watched theme';
  static const day6Job = 'Review what changed';
  static const day7Job = 'Complete your first archive review';

  static String weeklyReviewRoute({required bool hasWeeklyReviewAvailable}) =>
      hasWeeklyReviewAvailable
          ? WeeklyArchiveReviewNavigation.route
          : archiveHomeRoute;

  static String weeklyReviewCta({required bool hasWeeklyReviewAvailable}) =>
      hasWeeklyReviewAvailable ? openWeeklyReviewCta : reviewArchiveCta;

  /// All user-visible strings for copy safety tests.
  static List<String> get allVisibleStrings => [
        screenTitle,
        cardLabel,
        startTitle,
        startBody,
        saveFirstMomentCta,
        saveMomentCta,
        openBetaFeedbackCta,
        pickWatchThemeCta,
        addThemeMomentCta,
        reviewChangesCta,
        openWeeklyReviewCta,
        reviewArchiveCta,
        openPathCta,
        viewFullPathCta,
        completeTitle,
        completeBody,
        screenshotCardTitle,
        screenshotCardBody,
        supportSectionTitle,
        supportSectionBody,
        helpSectionTitle,
        helpSectionBullet,
        betaOutcomesLabel,
        day1Reward,
        day1Next,
        day2Reward,
        day2Next,
        day3Reward,
        day3Next,
        day4Reward,
        day4Next,
        day5Reward,
        day5Next,
        day6Reward,
        day6Next,
        day7Reward,
        day7Next,
        day1Job,
        day2Job,
        day3Job,
        day4Job,
        day5Job,
        day6Job,
        day7Job,
        progressLabel(1, 7),
        progressLabelStart(7),
      ];
}
