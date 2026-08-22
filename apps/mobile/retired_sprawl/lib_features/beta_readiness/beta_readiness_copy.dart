/// Copy for the local beta readiness checklist — release safety only.
abstract final class BetaReadinessCopy {
  BetaReadinessCopy._();

  static const openLink = 'Beta readiness check';
  static const sheetTitle = 'Beta readiness check';
  static const sheetIntro =
      'Local checklist for TestFlight. Automatic checks verify wiring only — '
      'walk through manual items on a device before release.';

  static const statusPass = 'Pass';
  static const statusNeedsManualCheck = 'Needs manual check';
  static const statusNotAvailable = 'Not available';

  static const sectionCapture = 'Capture';
  static const sectionFirstProof = 'First proof';
  static const sectionTrustControls = 'Trust controls';
  static const sectionReturnLoop = 'Return loop';
  static const sectionBetaFeedback = 'Beta feedback';
  static const sectionReleaseWarnings = 'Release warnings';

  // Capture
  static const itemFirstUseOnboardingAtZero =
      'First-use onboarding visible at zero entries';
  static const itemMicCtaPrimary = 'Mic CTA primary';
  static const itemTypedFallbackAvailable = 'Typed fallback available';
  static const itemNoDailyMapBeforeFirstSave = 'No daily map before first save';

  // First proof
  static const itemThreeMomentsUnlockFirstProof =
      '3 related real moments unlock first proof';
  static const itemGenericEntriesNoFirstProof =
      'Generic/test entries do not unlock first proof';
  static const itemFirstProofPayoffAppears = 'First proof payoff appears';
  static const itemFirstProofTruthFollowUp =
      'First proof truth follow-up appears';
  static const itemFirstProofActionLoopAfterAnswer =
      'First proof action loop appears after answer';

  // Trust controls
  static const itemSavedMomentsOpens = 'Saved moments opens';
  static const itemDeleteMomentAvailable = 'Delete moment available';
  static const itemRemoveFromPatternAvailable = 'Remove from pattern available';
  static const itemCorrectTranscriptAvailable = 'Correct transcript available';
  static const itemPrivacyCentreOpens = 'Privacy & your archive opens';
  static const itemExportLocalBackupAvailable = 'Export local backup available';
  static const itemRestoreLocalBackupAvailable =
      'Restore local backup available';

  // Return loop
  static const itemReturnTomorrowCue =
      'Return tomorrow cue after first/second useful moment';
  static const itemReturnDayFlowAvailable =
      'Return day flow available after grounded watch target';
  static const itemWhatChangedAfterFourthMoment =
      'What changed appears after fourth related moment';

  // Beta feedback
  static const itemSendBetaFeedbackAvailable = 'Send beta feedback available';
  static const itemBetaProgressSummaryAvailable =
      'Beta progress summary available';
  static const itemCopySummaryWorks = 'Copy summary works';

  // Release warnings — informational only
  static const warningAppStoreProducts =
      'RevenueCat products may still need App Store Connect verification';
  static const warningLocalBackupPlainJson =
      'Local backup is plain JSON, not encrypted';
  static const warningArchiveLocalUnlessExport =
      'Archive is local unless user exports backup';

  static List<String> allVisibleStrings() => [
    openLink,
    sheetTitle,
    sheetIntro,
    statusPass,
    statusNeedsManualCheck,
    statusNotAvailable,
    sectionCapture,
    sectionFirstProof,
    sectionTrustControls,
    sectionReturnLoop,
    sectionBetaFeedback,
    sectionReleaseWarnings,
    itemFirstUseOnboardingAtZero,
    itemMicCtaPrimary,
    itemTypedFallbackAvailable,
    itemNoDailyMapBeforeFirstSave,
    itemThreeMomentsUnlockFirstProof,
    itemGenericEntriesNoFirstProof,
    itemFirstProofPayoffAppears,
    itemFirstProofTruthFollowUp,
    itemFirstProofActionLoopAfterAnswer,
    itemSavedMomentsOpens,
    itemDeleteMomentAvailable,
    itemRemoveFromPatternAvailable,
    itemCorrectTranscriptAvailable,
    itemPrivacyCentreOpens,
    itemExportLocalBackupAvailable,
    itemRestoreLocalBackupAvailable,
    itemReturnTomorrowCue,
    itemReturnDayFlowAvailable,
    itemWhatChangedAfterFourthMoment,
    itemSendBetaFeedbackAvailable,
    itemBetaProgressSummaryAvailable,
    itemCopySummaryWorks,
    warningAppStoreProducts,
    warningLocalBackupPlainJson,
    warningArchiveLocalUnlessExport,
  ];
}