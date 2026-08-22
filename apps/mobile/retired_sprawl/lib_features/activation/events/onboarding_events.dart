/// Tier 1 — trial / cold-start funnel event names.
abstract final class OnboardingEvents {
  static const trialAppOpened = 'trialAppOpened';
  static const trialRecordCtaTapped = 'trialRecordCtaTapped';
  static const trialMicPermissionRequested = 'trialMicPermissionRequested';
  static const trialMicPermissionDenied = 'trialMicPermissionDenied';
  static const trialRecordingStarted = 'trialRecordingStarted';
  static const trialRecordingCancelled = 'trialRecordingCancelled';
  static const trialSaveStarted = 'trialSaveStarted';
  static const trialSaveCompleted = 'trialSaveCompleted';
  static const trialClosedBeforeWatchForAccepted =
      'trialClosedBeforeWatchForAccepted';
  static const trialExportCopied = 'trialExportCopied';
}