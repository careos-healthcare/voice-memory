// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get accountAuthCodeBody => 'Enter the sign-in code we just sent you.';

  @override
  String get accountAuthCodeCta => 'Continue';

  @override
  String get accountAuthCodeLabel => 'Code';

  @override
  String get accountAuthCodeSent => 'Code sent — check your email.';

  @override
  String get accountAuthCodeTitle => 'Check your email';

  @override
  String get accountAuthContinueWithoutAccount => 'Continue without an account';

  @override
  String get accountAuthCreateBody =>
      'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. Create an account to restore access later.';

  @override
  String get accountAuthCreateCta => 'Create account';

  @override
  String get accountAuthCreateTitle => 'Create your ArchiveMe account';

  @override
  String get accountAuthEmailLabel => 'Email';

  @override
  String get accountAuthInvalidCode => 'Enter the code from your email.';

  @override
  String get accountAuthInvalidEmail => 'Enter a valid email address.';

  @override
  String get accountAuthPrivacyLine =>
      'Your archive stays private. We do not include your recordings in analytics.';

  @override
  String get accountAuthResendCode => 'Resend code';

  @override
  String get accountAuthSendCodeFailed => 'Could not send the code.';

  @override
  String get accountAuthSignInCta => 'Sign in';

  @override
  String get accountAuthSignInFailed =>
      'Sign-in failed. Check the code and try again.';

  @override
  String get accountAuthSignInTitle => 'Sign in to ArchiveMe';

  @override
  String get accountAuthSignOut => 'Sign out';

  @override
  String get accountAuthSignOutKeepsArchive =>
      'Signing out keeps your recordings on this device.';

  @override
  String get accountAuthTimingNote =>
      'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. You can use it locally without an account.';

  @override
  String get accountScreenLabel => 'Account screen';

  @override
  String get appTitle => 'ArchiveMe';

  @override
  String get archiveAddMoment => 'Add a moment';

  @override
  String archiveCurrentObservation(String statement) {
    return 'Your clearest current observation is: $statement';
  }

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
  String get archiveEvidenceTitle => 'Evidence';

  @override
  String get archiveNeedsComparison =>
      'Add another moment so ArchiveMe can compare what changed.';

  @override
  String get archiveNeedsSupportedMoments =>
      'ArchiveMe needs at least two supported moments before explaining a pattern.';

  @override
  String get archiveNextMomentGuidance =>
      'Record or type one specific moment. A second supported observation makes change visible.';

  @override
  String get archiveNextStepsTitle => 'Next steps';

  @override
  String get archiveScreenLabel => 'Archive screen';

  @override
  String get archiveTitle => 'Archive';

  @override
  String get archiveWhatChangedTitle => 'What changed?';

  @override
  String get archiveWhyTitle => 'Why?';

  @override
  String get authTriggerArchiveChangedReturnCta => 'Protect archive';

  @override
  String get authTriggerArchiveChangedReturnLead =>
      'Sign in to protect your archive after it may have shifted.';

  @override
  String get authTriggerArchiveChangedReturnTitle =>
      'See what your archive believes now';

  @override
  String get authTriggerCrossDeviceCta => 'Sign in to continue';

  @override
  String get authTriggerCrossDeviceLead =>
      'Sign in to pick up your archive where you left off.';

  @override
  String get authTriggerCrossDeviceTitle => 'Continue on another device';

  @override
  String get authTriggerExportCta => 'Sign in to export';

  @override
  String get authTriggerExportLead => 'Sign in before exporting your archive.';

  @override
  String get authTriggerExportTitle => 'Export with a protected account';

  @override
  String get authTriggerFirstWorkingBeliefCta => 'Protect this belief';

  @override
  String get authTriggerFirstWorkingBeliefLead =>
      'Sign in to protect the belief your archive is forming.';

  @override
  String get authTriggerFirstWorkingBeliefTitle =>
      'Your archive has a working belief';

  @override
  String get authTriggerKeepTrackingProCta => 'Sign in to continue';

  @override
  String get authTriggerKeepTrackingProLead =>
      'Sign in before upgrading so your archive stays backed up.';

  @override
  String get authTriggerKeepTrackingProTitle => 'Keep tracking with Pro';

  @override
  String get authTriggerProPaywallCta => 'Continue with email';

  @override
  String get authTriggerProPaywallLead =>
      'Checkout needs an account to protect your archive.';

  @override
  String get authTriggerProPaywallTitle => 'Sign in for Pro';

  @override
  String get authTriggerProtectArchiveCta => 'Protect with email';

  @override
  String get authTriggerProtectArchiveLead =>
      'Sign in with email to encrypt a backup of what you built on this device.';

  @override
  String get authTriggerProtectArchiveTitle => 'Protect this archive';

  @override
  String get authTriggerSyncArchiveCta => 'Sign in to sync';

  @override
  String get authTriggerSyncArchiveLead =>
      'Email sign-in enables encrypted sync on this device.';

  @override
  String get authTriggerSyncArchiveTitle => 'Back up your archive';

  @override
  String get changesScreenLabel => 'Changes screen';

  @override
  String coachingConfidence(int percentage) {
    return '$percentage% confidence';
  }

  @override
  String coachingConfidenceSemantics(int percentage) {
    return 'Confidence $percentage percent';
  }

  @override
  String get coachingInsightHint =>
      'AI-generated reflection based on recent journal evidence.';

  @override
  String coachingInsightSemantics(
    String category,
    int percentage,
    String content,
  ) {
    return '$category. Confidence $percentage percent. $content';
  }

  @override
  String get commonNotNow => 'Not now';

  @override
  String get dataPortabilityTrustFooter =>
      'Exported from your device. Your own voice — not therapy or diagnosis.';

  @override
  String get exportJsonCta => 'Export JSON';

  @override
  String get exportPortabilityBusy => 'Building export…';

  @override
  String get exportPortabilityCta => 'Download full archive (ZIP)';

  @override
  String get exportPortabilityFailed => 'Export failed. Try again.';

  @override
  String get exportPortabilitySuccess =>
      'Export ready — share or save the ZIP file.';

  @override
  String get exportScreenLead =>
      'Download a portable copy of your archive for backup or migration.';

  @override
  String get exportScreenTitle => 'Export';

  @override
  String get memoryGraphActionBarHint =>
      'Swipe horizontally to explore more graph actions.';

  @override
  String get memoryGraphActionBarLabel => 'Memory Graph actions';

  @override
  String get memoryGraphActionButtonHint =>
      'Double tap to activate this graph action.';

  @override
  String get memoryGraphClosePreview => 'Close Preview';

  @override
  String get memoryGraphCloseRewind => 'Close Rewind';

  @override
  String memoryGraphClusters(int count) {
    return 'Clusters $count';
  }

  @override
  String get memoryGraphDocuments => 'Documents';

  @override
  String get memoryGraphLifeDashboard => 'Life Dashboard';

  @override
  String get memoryGraphLifeSimulator => 'Life Simulator';

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
  String get memoryGraphPreview => 'Preview Graph';

  @override
  String get memoryGraphReturnToPresent => 'Return to Present';

  @override
  String get memoryGraphSampleBadge => 'Sample Mind · illustrative';

  @override
  String get memoryGraphSmallSteps => 'Small steps';

  @override
  String get memoryGraphTimeMachine => 'Time Machine';

  @override
  String get memoryGraphWeekly => 'Weekly';

  @override
  String get memoryGraphWidgets => 'Widgets';

  @override
  String get meshNoPeers => 'No paired devices are nearby.';

  @override
  String get meshPairDevice => 'Pair a device';

  @override
  String get meshPrivacyDescription =>
      'Nearby discovery advertises only a rotating identifier. Archive metadata is exchanged after encrypted pairing.';

  @override
  String get meshReadOnlyBranch => 'Read-only shared branch';

  @override
  String get meshShareCluster => 'Share this cluster';

  @override
  String get meshStatusComplete => 'Local sync complete';

  @override
  String get meshStatusConnected => 'Connected securely';

  @override
  String get meshStatusSearching => 'Searching nearby';

  @override
  String get meshStatusTitle => 'Nearby encrypted sync';

  @override
  String get meshSyncNow => 'Sync nearby';

  @override
  String get navigationAccount => 'Account';

  @override
  String get navigationArchive => 'Archive';

  @override
  String get navigationChanges => 'Changes';

  @override
  String get navigationRecord => 'Record';

  @override
  String get primaryNavigationLabel => 'Primary navigation';

  @override
  String get recapCopied => 'Recap copied.';

  @override
  String get recordScreenLabel => 'Record screen';

  @override
  String get recordingCopyRecap => 'Copy recap';

  @override
  String get recordingEnoughForNow => 'That\'s enough for now';

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
  String get recordingPlainLanguageHint =>
      'Say it plainly. ArchiveMe looks for patterns, not judgment.';

  @override
  String get recordingProcessingStatus => 'Processing';

  @override
  String get recordingPromptNudgeBody =>
      'ArchiveMe uses what you record to surface sharper things worth checking each day.';

  @override
  String get recordingPromptNudgeTitle =>
      'Keep your daily archive prompts improving';

  @override
  String get recordingReadyStatus => 'Ready to record';

  @override
  String get recordingSavedBackgroundTranscription =>
      'Recording saved. Transcription will finish in the background.';

  @override
  String get recordingSavedStatus => 'Saved';

  @override
  String get recordingStatus => 'Recording';

  @override
  String get recordingStopAndSaveHint =>
      'Tap Stop and save when you are finished.';

  @override
  String get recordingUnlockPro => 'Unlock Pro';

  @override
  String get savedForNextCheckIn => 'Saved for your next check-in.';

  @override
  String get savedForNextMonthCheck => 'Saved for next month\'s check.';

  @override
  String get savedForTomorrowCheck => 'Saved for tomorrow\'s check.';

  @override
  String get textJournalPanelLead =>
      'No microphone needed — a few sentences is enough for your archive.';

  @override
  String get textJournalPanelTitle => 'Type a moment';

  @override
  String get textJournalSaveCta => 'Save thought';

  @override
  String get tomorrowCheckSet => 'Tomorrow\'s check is set.';

  @override
  String get watchQuickRecordCta => 'Start recording';

  @override
  String get watchQuickRecordTitle => 'Quick record';

  @override
  String get widgetQuickCaptureAction => 'Record';

  @override
  String get widgetQuickCaptureBody =>
      'Capture a moment from your home screen.';

  @override
  String get accountTitle => 'ArchiveMe account';

  @override
  String get syncStatus => 'Sync status';

  @override
  String get syncNotAvailableTestFlight =>
      'Sync is not available in this TestFlight build.';

  @override
  String get syncOnDeviceOnly => 'On this device';

  @override
  String get syncNow => 'Sync now';

  @override
  String get accountPrivacyNote =>
      'Your recordings stay on this device unless you sign in to sync.';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get settings => 'Settings';

  @override
  String get accountSessionLoading => 'Loading…';

  @override
  String get accountNotSignedIn => 'Not signed in';

  @override
  String get accountSignedIn => 'Signed in';

  @override
  String get accountSignedInForSync => 'Signed in for sync';

  @override
  String get accountLastSyncedToday => 'Last synced today';

  @override
  String get recordTitle => 'What is on your mind?';

  @override
  String get recordSubtitle => 'Say one small thing from today.';

  @override
  String get recordOneMomentCta => 'Record one moment';

  @override
  String get recordMomentCta => 'Record moment';

  @override
  String get stopRecordingCta => 'Stop recording';

  @override
  String get recordAnotherCta => 'Record another';

  @override
  String get recordNextMomentCta => 'Record next moment';

  @override
  String get startRecording => 'Start recording';

  @override
  String get trySayingOneOfThese => 'Try saying one of these';

  @override
  String get recordHelpSheetTitle => 'Pick a prompt';

  @override
  String get recordHelpSheetHelper => 'Choose one, then record one sentence.';

  @override
  String get reflectionSavedTitle => 'Reflection saved';

  @override
  String get postSaveRecordAnother => 'Record another moment';

  @override
  String get viewPatternsCta => 'View patterns';

  @override
  String get back => 'Back';

  @override
  String get firstSavePostSaveTitle => 'Saved.';

  @override
  String get firstSavePostSaveBody => 'Come back when this shows up again.';

  @override
  String get finishRecordingFirst => 'Finish or cancel the recording first.';

  @override
  String get paywallHeadline => 'You saw the first useful repeat.';

  @override
  String get paywallSubhead =>
      'Free shows the first useful proof. Pro keeps the longer trail.';

  @override
  String get paywallPrimaryCta => 'Keep the longer trail';

  @override
  String get paywallSecondaryCta => 'Not now';

  @override
  String get paywallContinue => 'Keep the longer trail';

  @override
  String get paywallDifferentiation =>
      'ArchiveMe is not trying to answer better than ChatGPT. It is trying to remember differently.';

  @override
  String get paywallTrust =>
      'Your saves stay free. Manage or cancel anytime in the App Store.';

  @override
  String get paywallBackupLine =>
      'You are building evidence over time. Pro keeps the longer proof trail as moments return, change, or fade.';

  @override
  String get paywallPrimaryValueBlock =>
      'Pro keeps a longer private archive — more moments, more continuity, more evidence over time.';

  @override
  String get paywallBackToPatterns => 'Back to Patterns';

  @override
  String get restorePurchases => 'Restore purchases';

  @override
  String get paywallAnchorPositioningLine =>
      'Keep your verified timeline growing.';

  @override
  String get paywallProofConnectedLine =>
      'Pro keeps a longer private archive — more moments, more continuity, more evidence over time.';

  @override
  String get paywallSecondaryReassurance =>
      'You stay in control. You can delete entries and correct what you saved.';

  @override
  String get paywallBenefitBullet1 => 'Longer evidence history on this device';

  @override
  String get paywallBenefitBullet2 =>
      'More archived moments over weeks and months';

  @override
  String get paywallBenefitBullet3 =>
      'Continuity when patterns return or change';

  @override
  String get paywallSetupUnavailableBody =>
      'Plans are not available right now.';

  @override
  String get paywallUnavailablePlansLoading => 'Loading plans…';

  @override
  String get valueMomentProTitle => 'Keep the longer proof trail';

  @override
  String get valueMomentProCta => 'See Pro';

  @override
  String get valueMomentProDismiss => 'Not now';

  @override
  String get valueMomentThreadReturnBody =>
      'This thread has returned before. Pro keeps the evidence history so ArchiveMe can show whether it gets stronger, softer, or changes.';

  @override
  String get valueMomentBeliefBody =>
      'A belief-like phrase showed up again. Pro keeps the timeline of what changed across your archive.';

  @override
  String get valueMomentWeeklyBody =>
      'Your weekly review found something to compare. Pro keeps weekly archive reviews so ArchiveMe can track what changed over time.';

  @override
  String get valueMomentProofCounterBody =>
      'Your archive has connected recordings. Pro keeps the full evidence history as the trail grows.';

  @override
  String get valueMomentFallbackBody =>
      'Your first repeat is free. Pro keeps the evidence history so ArchiveMe can show whether patterns get stronger, softer, or change over time.';

  @override
  String get subscriptionPaywallNoOfferings =>
      'No subscription plans are available.';

  @override
  String get purchaseSuccess => 'Pro is active.';

  @override
  String get restorePurchasesError => 'Could not restore purchases.';

  @override
  String get patternsTabLabel => 'Archive';

  @override
  String get patternsEmptyPageTitle => 'Record a few real moments';

  @override
  String get patternsEarlyStateBody =>
      'Record a few real moments. ArchiveMe will look for what repeats across them.';

  @override
  String get patternsEmptyCta => 'Record moment';

  @override
  String get patternsHeroHeading => 'WHAT KEEPS REPEATING IN YOUR LIFE';

  @override
  String get patternsShiftingHeading => 'WHAT MAY BE CHANGING';

  @override
  String get patternsEvolutionHeading => 'CHANGING OVER TIME';

  @override
  String get patternsSectionCurrent => 'Patterns that keep repeating';

  @override
  String get patternsSectionEmerging => 'A pattern is forming';

  @override
  String get patternsSectionChanging => 'This seems to be changing';

  @override
  String get patternsFirstEntrySavedTitle => 'First moment saved';

  @override
  String get patternsFirstEntrySavedBody =>
      'Record one more clear moment and ArchiveMe can compare what repeats.';

  @override
  String get patternsFirstEntrySavedCta => 'Record another moment';

  @override
  String get patternsFirstEntryViewSavedCta => 'View saved entry';

  @override
  String get patternsHowItWorksTitle => 'How it works';

  @override
  String get patternsPrivacyReassurance =>
      'Private on your device. Nothing is shared without you choosing to.';

  @override
  String get allPatternsTitle => 'All patterns';

  @override
  String get allPatternsLead =>
      'Patterns and themes ArchiveMe keeps noticing in your reflections.';

  @override
  String get patternsCheckInWaitingTitle => 'Check-in waiting';

  @override
  String get patternsCheckInWaitingBody =>
      'ArchiveMe has a question from your last moment.';

  @override
  String get patternsCheckInWaitingCta => 'Answer it now';

  @override
  String get patternsLoopClosedTitle => 'Loop closed';

  @override
  String get patternsRecordAnotherMomentCta => 'Record another moment';

  @override
  String get patternsResultUseCheckCta => 'Use this check';

  @override
  String get patternsSignalsWaitingTitle => 'Signals waiting for clarity';

  @override
  String get patternsWatchingSignalTitle => 'ArchiveMe is watching this signal';

  @override
  String get patternsWatchingSignalBody =>
      'Record one more moment to test whether it repeats.';

  @override
  String get archiveDiscoverPatternsLink => 'See all patterns';

  @override
  String get archiveTimelineLink => 'Timeline';

  @override
  String get archiveSearchLink => 'Search archive';

  @override
  String get activePatternCurrentTitle => 'Current pattern';

  @override
  String get activePatternRecordTodayCta => 'Record today';

  @override
  String get seeWhatChanged => 'See what changed';

  @override
  String get patternsComeBackTitle => 'Why come back tomorrow?';

  @override
  String get patternsComeBackBody =>
      'ArchiveMe compares what you save over time.';

  @override
  String get patternsComeBackRecordCta => 'Record today\'s reflection';
}
