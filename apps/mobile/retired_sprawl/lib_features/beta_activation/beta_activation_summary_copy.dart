import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_model.dart';

/// Copy for local beta activation summary — metadata only.
abstract final class BetaActivationSummaryCopy {
  BetaActivationSummaryCopy._();

  static const sheetTitle = 'Beta progress summary';
  static const sheetIntro =
      'Local counters for this device only. Nothing is sent automatically.';
  static const statusHeading = 'Activation status';
  static const countersHeading = 'Loop counters';
  static const copySummaryButton = 'Copy summary';
  static const summaryCopied = 'Summary copied';
  static const openLink = 'Beta progress summary';

  static const appOpens = 'App opens';
  static const recordScreenViews = 'Record screen views';
  static const firstMomentSaved = 'First moment saved';
  static const secondMomentSaved = 'Second moment saved';
  static const firstProofReached = 'First proof reached';
  static const patternsOpened = 'Patterns opened';
  static const patternDetailsOpened = 'Pattern details opened';
  static const weeklyReviewOpened = 'Weekly review opened';
  static const returnDayFlowAnswered = 'Return day flow answered';
  static const transcriptCorrected = 'Transcript corrected';
  static const betaFeedbackOpened = 'Beta feedback opened';
  static const betaFeedbackSubmitted = 'Beta feedback submitted';
  static const firstProofTruthYes = 'First proof truth: yes';
  static const firstProofTruthSortOf = 'First proof truth: sort of';
  static const firstProofTruthNo = 'First proof truth: no';
  static const firstProofActionWatchThisNext =
      'First proof action: watch this next';
  static const firstProofActionViewPatternDetails =
      'First proof action: view pattern details';
  static const firstProofActionRenamePattern =
      'First proof action: rename pattern';
  static const firstProofActionKeepRecording =
      'First proof action: keep recording';
  static const firstProofActionCorrectTranscript =
      'First proof action: correct words';
  static const firstProofActionRemoveFromPattern =
      'First proof action: remove from pattern';
  static const proScreenOpened = 'Pro screen opened';
  static const restorePurchasesTapped = 'Restore purchases tapped';

  static String statusLabel(BetaActivationStatus status) => switch (status) {
    BetaActivationStatus.notStarted => 'Not started',
    BetaActivationStatus.firstMomentSaved => 'First moment saved',
    BetaActivationStatus.almostAtFirstProof => 'Almost at first proof',
    BetaActivationStatus.firstProofReached => 'First proof reached',
    BetaActivationStatus.returnedAfterProof => 'Returned after proof',
    BetaActivationStatus.weeklyReviewReached => 'Weekly review reached',
  };

  static List<String> allVisibleCopy() => [
    sheetTitle,
    sheetIntro,
    statusHeading,
    countersHeading,
    copySummaryButton,
    summaryCopied,
    openLink,
    appOpens,
    recordScreenViews,
    firstMomentSaved,
    secondMomentSaved,
    firstProofReached,
    patternsOpened,
    patternDetailsOpened,
    weeklyReviewOpened,
    returnDayFlowAnswered,
    transcriptCorrected,
    betaFeedbackOpened,
    betaFeedbackSubmitted,
    firstProofTruthYes,
    firstProofTruthSortOf,
    firstProofTruthNo,
    firstProofActionWatchThisNext,
    firstProofActionViewPatternDetails,
    firstProofActionRenamePattern,
    firstProofActionKeepRecording,
    firstProofActionCorrectTranscript,
    firstProofActionRemoveFromPattern,
    proScreenOpened,
    restorePurchasesTapped,
    ...BetaActivationStatus.values.map(statusLabel),
  ];
}