/// Copy for the release candidate smoke test — developer diagnostics only.
abstract final class ReleaseCandidateSmokeCopy {
  ReleaseCandidateSmokeCopy._();

  static const sectionTitle = 'Release candidate smoke test';

  static const manualChecklistTitle = 'Manual TestFlight smoke checklist';

  static const summaryReady = 'Ready for TestFlight smoke test';

  static const summaryNeedsAttention = 'Needs attention before TestFlight';

  static const statusReady = 'Ready';

  static const statusCheckManually = 'Check manually';

  static const statusMissing = 'Missing';

  static const rowFirstLaunchRecord = 'First launch opens Record';

  static const rowFirstUseCapture = 'First-use capture visible';

  static const rowSaveOneMoment = 'Save one moment path available';

  static const rowSecondMomentGuidance = 'Second moment guidance available';

  static const rowFirstProofPath = 'First proof path available';

  static const rowCoreValueFeedback = 'Core value feedback prompt available';

  static const rowPatternsArchive = 'Patterns archive path available';

  static const rowEvidenceTimeline = 'Evidence timeline path available';

  static const rowPrivateReportPreview = 'Private report preview available';

  static const rowProRoute = 'Pro route available';

  static const rowRestorePurchasesRoute = 'Restore purchases route available';

  static const rowDeveloperDiagnosticsLocked =
      'Developer diagnostics locked in production';

  static const rowMicrophonePermissionCopy =
      'Microphone permission copy available';

  static const rowSaveFailureCopy = 'Save failure copy available';

  static const rowPrivacySupportLink = 'Privacy/support link available';

  static const rowResetArchiveControl = 'Reset/archive control available';

  static const rowReportCopy = 'Report copy available';

  static const recordRoute = '/record';

  static const patternsRoute = '/archive-belief';

  static const proRoute = '/subscription';

  static const restorePurchasesRoute = '/restore-purchases';

  static const developerDiagnosticsRoute = '/developer-diagnostics';

  static const manualChecklistSteps = [
    'Install fresh build',
    'Open app',
    'Confirm Record is clear',
    'Save first moment',
    'Save second similar moment',
    'Save third related moment',
    'Confirm first proof appears',
    'Answer beta feedback',
    'Open Patterns',
    'Confirm belief and evidence timeline appear',
    'Tap See Pro',
    'Confirm restore purchases is visible',
    'Return to app without crash',
  ];
}