/// Calm, evidence-based copy for the daily archive exercise.
abstract final class DailyArchiveExerciseCopy {
  DailyArchiveExerciseCopy._();

  static const route = '/daily-archive-exercise';
  static const recordRoute = '/record';
  static const betaFeedbackRoute = '/beta-feedback';
  static const archiveHomeRoute = '/archive-belief';

  static const screenTitle = 'Daily archive exercise';
  static const cardLabel = "Today's archive exercise";
  static const recordLabel = "Today's exercise";

  static const saveMomentCta = 'Save a moment';
  static const openExerciseCta = 'Open exercise';
  static const openBetaFeedbackCta = 'Open beta feedback';
  static const viewFullExerciseCta = 'View full exercise';

  static const screenshotTitle = 'Daily archive exercise (sample)';
  static const screenshotPrompt =
      'ArchiveMe suggests one useful evidence-based action each day. Example only — no private data.';

  static const firstMomentPrompt =
      'Save one useful moment your future archive can compare.';
  static const comparisonPrompt =
      'Save one moment where a familiar pattern nearly repeated.';
  static const watchThemePrompt = 'Add one example of your current watch theme.';
  static const betaFeedbackPrompt =
      'Open beta feedback and mark whether your archive has been useful so far.';
  static const patternRepeatedPrompt =
      'Save one moment where a familiar pattern nearly repeated.';
  static const feltDifferentPrompt =
      'Record one moment that felt different from usual.';
  static const checkConcernPrompt =
      'Check whether yesterday\'s concern showed up again.';
  static const saveUsefulPrompt =
      'Save one useful moment your future archive can compare.';

  static const firstMomentHint =
      'Start with one concrete moment ArchiveMe can build on.';
  static const comparisonHint =
      'A second or third moment helps ArchiveMe compare over time.';
  static const watchThemeHint =
      'Add evidence around what you are already watching.';
  static const betaFeedbackHint =
      'Your feedback stays on this device only.';
  static const varietyHint =
      'One small moment today keeps your archive useful tomorrow.';

  static const firstMomentTitle = 'Start your archive';
  static const comparisonTitle = 'Build comparison material';
  static const watchThemeTitle = 'Add watch-theme evidence';
  static const betaFeedbackTitle = 'Share local beta feedback';
  static const varietyTitle = 'One useful action today';

  static List<String> get allVisibleStrings => [
        screenTitle,
        cardLabel,
        recordLabel,
        saveMomentCta,
        openExerciseCta,
        openBetaFeedbackCta,
        viewFullExerciseCta,
        screenshotTitle,
        screenshotPrompt,
        firstMomentPrompt,
        comparisonPrompt,
        watchThemePrompt,
        betaFeedbackPrompt,
        patternRepeatedPrompt,
        feltDifferentPrompt,
        checkConcernPrompt,
        saveUsefulPrompt,
        firstMomentHint,
        comparisonHint,
        watchThemeHint,
        betaFeedbackHint,
        varietyHint,
        firstMomentTitle,
        comparisonTitle,
        watchThemeTitle,
        betaFeedbackTitle,
        varietyTitle,
      ];
}
