/// Calm, mind-map prompt copy for the daily Record tab nudge.
abstract final class DailyArchiveExerciseCopy {
  DailyArchiveExerciseCopy._();

  static const route = '/daily-archive-exercise';
  static const recordRoute = '/record';
  static const betaFeedbackRoute = '/beta-feedback';
  static const archiveHomeRoute = '/archive-belief';

  static const recordLabel = "Today's map prompt";
  static const String screenTitle = recordLabel;
  static const String cardLabel = recordLabel;

  static const saveMomentCta = 'Save one moment';
  static const openExerciseCta = 'Open prompt';
  static const openBetaFeedbackCta = 'Open beta feedback';
  static const viewFullExerciseCta = 'View full prompt';

  static const screenshotTitle = "Today's map prompt (sample)";
  static const screenshotPrompt =
      'ArchiveMe suggests one useful evidence-based action each day. Example only — no private data.';

  static const firstMomentPrompt =
      'Add one real moment to your private mind map.';
  static const comparisonPrompt =
      'Add another moment so ArchiveMe can start seeing what connects.';
  static const watchThemePrompt =
      'Record what happened just before this showed up again.';
  static const betaFeedbackPrompt =
      'Open beta feedback and mark whether your archive has been useful so far.';
  static const patternRepeatedPrompt =
      'Record what happened just before this showed up again.';
  static const feltDifferentPrompt = 'Record what felt different this time.';
  static const checkConcernPrompt = 'Map the moment before you said yes.';
  static const saveUsefulPrompt =
      'Add one real moment to your private mind map.';

  static const firstMomentHint =
      'One concrete moment is enough to start your private map.';
  static const comparisonHint =
      'A few real moments help ArchiveMe notice what connects.';
  static const watchThemeHint =
      'Capture what was happening when this thread showed up again.';
  static const betaFeedbackHint = 'Your feedback stays on this device only.';
  static const varietyHint =
      'One useful moment keeps your private mind map clearer.';

  static const firstMomentTitle = "Today's map prompt";
  static const comparisonTitle = "Today's map prompt";
  static const watchThemeTitle = "Today's map prompt";
  static const betaFeedbackTitle = 'Share local beta feedback';
  static const varietyTitle = "Today's map prompt";

  /// Strings shown on the Record tab daily map prompt card.
  static List<String> get recordVisibleStrings => [
    recordLabel,
    saveMomentCta,
    firstMomentPrompt,
    comparisonPrompt,
    watchThemePrompt,
    patternRepeatedPrompt,
    feltDifferentPrompt,
    checkConcernPrompt,
    saveUsefulPrompt,
    firstMomentHint,
    comparisonHint,
    watchThemeHint,
    varietyHint,
    firstMomentTitle,
    comparisonTitle,
    watchThemeTitle,
    varietyTitle,
  ];

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