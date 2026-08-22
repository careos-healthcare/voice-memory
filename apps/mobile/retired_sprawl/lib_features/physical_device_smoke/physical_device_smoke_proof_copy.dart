/// Physical device smoke proof copy — iPhone/iPad release checklist only.
abstract final class PhysicalDeviceSmokeProofCopy {
  PhysicalDeviceSmokeProofCopy._();

  static const headline = 'Physical device smoke proof';

  static const body =
      'Real-device smoke checklist for iPhone and iPad before TestFlight or '
      'App Store submission. Proof only — no feature changes.';

  static const manualNote =
      'Most capture, purchase, and permission steps require a physical iPhone '
      'or iPad. Automated checks verify routes, copy, and log safety only.';

  static const statusPass = 'Pass';
  static const statusFail = 'Fail';
  static const statusPending = 'Pending';
  static const statusBlocked = 'Blocked';

  static const checkFreshInstallOpens = 'Fresh install opens';
  static const checkAppNameArchiveMe = 'App name ArchiveMe';
  static const checkLaunchScreenOk = 'Launch screen OK';
  static const checkMicPermissionAcceptPath = 'Mic permission accept path';
  static const checkMicPermissionDenyPath = 'Mic permission deny path';
  static const checkTypedSave = 'Typed save';
  static const checkVoiceSave = 'Voice save';
  static const checkTranscriptAppears = 'Transcript appears';
  static const checkPostSaveReinforcementAppears =
      'Post-save reinforcement appears';
  static const checkFirstProofPath = 'First proof path';
  static const checkCorrectionPath = 'Correction path';
  static const checkProScreenOpens = 'Pro screen opens';
  static const checkRevenueCatProductLoad = 'RevenueCat product load';
  static const checkPurchaseUnavailableCopySafe =
      'Purchase unavailable copy safe when key missing';
  static const checkRestorePathOpens = 'Restore path opens';
  static const checkPrivacyTermsSupportRoutesOpen =
      'Privacy, terms, and support routes open';
  static const checkOfflineLaunchSafe = 'Offline launch safe';
  static const checkNoCrash = 'No crash';
  static const checkNoPrivateTextLeakedInLogs =
      'No private text leaked in logs';

  static const detailPass = 'Verified';
  static const detailFail = 'Failed';
  static const detailPending = 'Run on physical device';
  static const detailBlocked = 'Blocked by earlier step';

  static const provedLine =
      'Physical device smoke proof complete for iPhone/iPad.';

  static const manualRequiredLine =
      'Automated smoke checks passed. Complete remaining steps on a physical device.';

  static const blockedLine =
      'Physical device smoke blocked. Fix the earliest failing check first.';

  static const guardrail =
      'Physical device smoke proof is a checklist only. Do not change product '
      'features, capture flow, or paywall mechanics while running smoke proof.';

  static String labelFor(PhysicalDeviceSmokeProofCheckId id) => switch (id) {
    PhysicalDeviceSmokeProofCheckId.freshInstallOpens => checkFreshInstallOpens,
    PhysicalDeviceSmokeProofCheckId.appNameArchiveMe => checkAppNameArchiveMe,
    PhysicalDeviceSmokeProofCheckId.launchScreenOk => checkLaunchScreenOk,
    PhysicalDeviceSmokeProofCheckId.micPermissionAcceptPath =>
      checkMicPermissionAcceptPath,
    PhysicalDeviceSmokeProofCheckId.micPermissionDenyPath =>
      checkMicPermissionDenyPath,
    PhysicalDeviceSmokeProofCheckId.typedSave => checkTypedSave,
    PhysicalDeviceSmokeProofCheckId.voiceSave => checkVoiceSave,
    PhysicalDeviceSmokeProofCheckId.transcriptAppears => checkTranscriptAppears,
    PhysicalDeviceSmokeProofCheckId.postSaveReinforcementAppears =>
      checkPostSaveReinforcementAppears,
    PhysicalDeviceSmokeProofCheckId.firstProofPath => checkFirstProofPath,
    PhysicalDeviceSmokeProofCheckId.correctionPath => checkCorrectionPath,
    PhysicalDeviceSmokeProofCheckId.proScreenOpens => checkProScreenOpens,
    PhysicalDeviceSmokeProofCheckId.revenueCatProductLoad =>
      checkRevenueCatProductLoad,
    PhysicalDeviceSmokeProofCheckId.purchaseUnavailableCopySafe =>
      checkPurchaseUnavailableCopySafe,
    PhysicalDeviceSmokeProofCheckId.restorePathOpens => checkRestorePathOpens,
    PhysicalDeviceSmokeProofCheckId.privacyTermsSupportRoutesOpen =>
      checkPrivacyTermsSupportRoutesOpen,
    PhysicalDeviceSmokeProofCheckId.offlineLaunchSafe => checkOfflineLaunchSafe,
    PhysicalDeviceSmokeProofCheckId.noCrash => checkNoCrash,
    PhysicalDeviceSmokeProofCheckId.noPrivateTextLeakedInLogs =>
      checkNoPrivateTextLeakedInLogs,
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield manualNote;
    yield statusPass;
    yield statusFail;
    yield statusPending;
    yield statusBlocked;
    yield checkFreshInstallOpens;
    yield checkAppNameArchiveMe;
    yield checkLaunchScreenOk;
    yield checkMicPermissionAcceptPath;
    yield checkMicPermissionDenyPath;
    yield checkTypedSave;
    yield checkVoiceSave;
    yield checkTranscriptAppears;
    yield checkPostSaveReinforcementAppears;
    yield checkFirstProofPath;
    yield checkCorrectionPath;
    yield checkProScreenOpens;
    yield checkRevenueCatProductLoad;
    yield checkPurchaseUnavailableCopySafe;
    yield checkRestorePathOpens;
    yield checkPrivacyTermsSupportRoutesOpen;
    yield checkOfflineLaunchSafe;
    yield checkNoCrash;
    yield checkNoPrivateTextLeakedInLogs;
    yield detailPass;
    yield detailFail;
    yield detailPending;
    yield detailBlocked;
    yield provedLine;
    yield manualRequiredLine;
    yield blockedLine;
    yield guardrail;
  }
}

enum PhysicalDeviceSmokeProofCheckId {
  freshInstallOpens,
  appNameArchiveMe,
  launchScreenOk,
  micPermissionAcceptPath,
  micPermissionDenyPath,
  typedSave,
  voiceSave,
  transcriptAppears,
  postSaveReinforcementAppears,
  firstProofPath,
  correctionPath,
  proScreenOpens,
  revenueCatProductLoad,
  purchaseUnavailableCopySafe,
  restorePathOpens,
  privacyTermsSupportRoutesOpen,
  offlineLaunchSafe,
  noCrash,
  noPrivateTextLeakedInLogs,
}

enum PhysicalDeviceSmokeProofStatus {
  pass,
  fail,
  pending,
  blocked;

  String get label => switch (this) {
    PhysicalDeviceSmokeProofStatus.pass =>
      PhysicalDeviceSmokeProofCopy.statusPass,
    PhysicalDeviceSmokeProofStatus.fail =>
      PhysicalDeviceSmokeProofCopy.statusFail,
    PhysicalDeviceSmokeProofStatus.pending =>
      PhysicalDeviceSmokeProofCopy.statusPending,
    PhysicalDeviceSmokeProofStatus.blocked =>
      PhysicalDeviceSmokeProofCopy.statusBlocked,
  };
}

enum PhysicalDeviceSmokeProofDecision { proved, manualRequired, blocked }