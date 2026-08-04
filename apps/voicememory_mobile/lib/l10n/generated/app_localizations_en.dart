// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountAuthCreateTitle => 'Create your ArchiveMe account';

  @override
  String get accountAuthCreateBody =>
      'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. Create an account to restore access later.';

  @override
  String get accountAuthCreateCta => 'Create account';

  @override
  String get accountAuthSignInTitle => 'Sign in to ArchiveMe';

  @override
  String get accountAuthSignInCta => 'Sign in';

  @override
  String get accountAuthEmailLabel => 'Email';

  @override
  String get accountAuthCodeTitle => 'Check your email';

  @override
  String get accountAuthCodeBody => 'Enter the sign-in code we just sent you.';

  @override
  String get accountAuthCodeLabel => 'Code';

  @override
  String get accountAuthCodeCta => 'Continue';

  @override
  String get accountAuthResendCode => 'Resend code';

  @override
  String get accountAuthCodeSent => 'Code sent — check your email.';

  @override
  String get accountAuthContinueWithoutAccount => 'Continue without an account';

  @override
  String get accountAuthPrivacyLine =>
      'Your archive stays private. We do not include your recordings in analytics.';

  @override
  String get accountAuthInvalidEmail => 'Enter a valid email address.';

  @override
  String get accountAuthInvalidCode => 'Enter the code from your email.';

  @override
  String get accountAuthSendCodeFailed => 'Could not send the code.';

  @override
  String get accountAuthSignInFailed =>
      'Sign-in failed. Check the code and try again.';

  @override
  String get accountAuthSignOut => 'Sign out';

  @override
  String get accountAuthSignOutKeepsArchive =>
      'Signing out keeps your recordings on this device.';

  @override
  String get accountAuthTimingNote =>
      'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. You can use it locally without an account.';

  @override
  String get authTriggerProtectArchiveTitle => 'Protect this archive';

  @override
  String get authTriggerProtectArchiveLead =>
      'Sign in with email to encrypt a backup of what you built on this device.';

  @override
  String get authTriggerProtectArchiveCta => 'Protect with email';

  @override
  String get authTriggerSyncArchiveTitle => 'Back up your archive';

  @override
  String get authTriggerSyncArchiveLead =>
      'Email sign-in enables encrypted sync on this device.';

  @override
  String get authTriggerSyncArchiveCta => 'Sign in to sync';

  @override
  String get authTriggerExportTitle => 'Export with a protected account';

  @override
  String get authTriggerExportLead => 'Sign in before exporting your archive.';

  @override
  String get authTriggerExportCta => 'Sign in to export';

  @override
  String get authTriggerProPaywallTitle => 'Sign in for Pro';

  @override
  String get authTriggerProPaywallLead =>
      'Checkout needs an account to protect your archive.';

  @override
  String get authTriggerProPaywallCta => 'Continue with email';

  @override
  String get authTriggerCrossDeviceTitle => 'Continue on another device';

  @override
  String get authTriggerCrossDeviceLead =>
      'Sign in to pick up your archive where you left off.';

  @override
  String get authTriggerCrossDeviceCta => 'Sign in to continue';

  @override
  String get authTriggerFirstWorkingBeliefTitle =>
      'Your archive has a working belief';

  @override
  String get authTriggerFirstWorkingBeliefLead =>
      'Sign in to protect the belief your archive is forming.';

  @override
  String get authTriggerFirstWorkingBeliefCta => 'Protect this belief';

  @override
  String get authTriggerArchiveChangedReturnTitle =>
      'See what your archive believes now';

  @override
  String get authTriggerArchiveChangedReturnLead =>
      'Sign in to protect your archive after it may have shifted.';

  @override
  String get authTriggerArchiveChangedReturnCta => 'Protect archive';

  @override
  String get authTriggerKeepTrackingProTitle => 'Keep tracking with Pro';

  @override
  String get authTriggerKeepTrackingProLead =>
      'Sign in before upgrading so your archive stays backed up.';

  @override
  String get authTriggerKeepTrackingProCta => 'Sign in to continue';

  @override
  String get meshStatusTitle => 'Nearby encrypted sync';

  @override
  String get meshStatusSearching => 'Searching nearby';

  @override
  String get meshStatusConnected => 'Connected securely';

  @override
  String get meshStatusComplete => 'Local sync complete';

  @override
  String get meshNoPeers => 'No paired devices are nearby.';

  @override
  String get meshPairDevice => 'Pair a device';

  @override
  String get meshSyncNow => 'Sync nearby';

  @override
  String get meshShareCluster => 'Share this cluster';

  @override
  String get meshReadOnlyBranch => 'Read-only shared branch';

  @override
  String get meshPrivacyDescription =>
      'Nearby discovery advertises only a rotating identifier. Archive metadata is exchanged after encrypted pairing.';

  @override
  String get primaryNavigationLabel => 'Primary navigation';

  @override
  String get recordScreenLabel => 'Record screen';

  @override
  String get archiveScreenLabel => 'Archive screen';

  @override
  String get changesScreenLabel => 'Changes screen';

  @override
  String get accountScreenLabel => 'Account screen';

  @override
  String get navigationRecord => 'Record';

  @override
  String get navigationArchive => 'Archive';

  @override
  String get navigationChanges => 'Changes';

  @override
  String get navigationAccount => 'Account';

  @override
  String get recordingStatus => 'Recording';

  @override
  String recordingInProgressSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Recording in progress, $_temp0';
  }

  @override
  String get recordingReadyStatus => 'Ready to record';

  @override
  String get recordingProcessingStatus => 'Processing';

  @override
  String get recordingSavedStatus => 'Saved';

  @override
  String get recordingStopAndSaveHint =>
      'Tap Stop and save when you are finished.';

  @override
  String get recordingSavedBackgroundTranscription =>
      'Recording saved. Transcription will finish in the background.';

  @override
  String get recordingPromptNudgeTitle =>
      'Keep your daily archive prompts improving';

  @override
  String get recordingPromptNudgeBody =>
      'ArchiveMe uses what you record to surface sharper things worth checking each day.';

  @override
  String get recordingUnlockPro => 'Unlock Pro';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get recordingPlainLanguageHint =>
      'Say it plainly. ArchiveMe looks for patterns, not judgment.';

  @override
  String get recordingCopyRecap => 'Copy recap';

  @override
  String get recordingEnoughForNow => 'That\'s enough for now';

  @override
  String get savedForNextCheckIn => 'Saved for your next check-in.';

  @override
  String get savedForTomorrowCheck => 'Saved for tomorrow\'s check.';

  @override
  String get savedForNextMonthCheck => 'Saved for next month\'s check.';

  @override
  String get tomorrowCheckSet => 'Tomorrow\'s check is set.';

  @override
  String get recapCopied => 'Recap copied.';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveWhatChangedTitle => 'What changed?';

  @override
  String get archiveWhyTitle => 'Why?';

  @override
  String get archiveEvidenceTitle => 'Evidence';

  @override
  String get archiveNextStepsTitle => 'Next steps';

  @override
  String get archiveAddMoment => 'Add a moment';

  @override
  String get archiveNeedsComparison =>
      'Add another moment so ArchiveMe can compare what changed.';

  @override
  String archiveCurrentObservation(String statement) {
    return 'Your clearest current observation is: $statement';
  }

  @override
  String get archiveNeedsSupportedMoments =>
      'ArchiveMe needs at least two supported moments before explaining a pattern.';

  @override
  String archiveEvidenceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saved moments available for comparison.',
      one: '1 saved moment available for comparison.',
    );
    return '$_temp0';
  }

  @override
  String get archiveNextMomentGuidance =>
      'Record or type one specific moment. A second supported observation makes change visible.';

  @override
  String coachingInsightSemantics(
    String category,
    int percentage,
    String content,
  ) {
    return '$category. Confidence $percentage percent. $content';
  }

  @override
  String get coachingInsightHint =>
      'AI-generated reflection based on recent journal evidence.';

  @override
  String coachingConfidence(int percentage) {
    return '$percentage% confidence';
  }

  @override
  String coachingConfidenceSemantics(int percentage) {
    return 'Confidence $percentage percent';
  }

  @override
  String get memoryGraphActionBarLabel => 'Memory Graph actions';

  @override
  String get memoryGraphActionBarHint =>
      'Swipe horizontally to explore more graph actions.';

  @override
  String get memoryGraphActionButtonHint =>
      'Double tap to activate this graph action.';

  @override
  String memoryGraphNodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nodes',
      one: '1 node',
    );
    return '$_temp0';
  }

  @override
  String get memoryGraphLifeSimulator => 'Life Simulator';

  @override
  String get memoryGraphSmallSteps => 'Small steps';

  @override
  String get memoryGraphWidgets => 'Widgets';

  @override
  String get memoryGraphDocuments => 'Documents';

  @override
  String get memoryGraphWeekly => 'Weekly';

  @override
  String memoryGraphClusters(int count) {
    return 'Clusters $count';
  }

  @override
  String get memoryGraphCloseRewind => 'Close Rewind';

  @override
  String get memoryGraphTimeMachine => 'Time Machine';

  @override
  String get memoryGraphLifeDashboard => 'Life Dashboard';

  @override
  String get memoryGraphClosePreview => 'Close Preview';

  @override
  String get memoryGraphPreview => 'Preview Graph';

  @override
  String get memoryGraphSampleBadge => 'Sample Mind · illustrative';

  @override
  String get memoryGraphReturnToPresent => 'Return to Present';
}
