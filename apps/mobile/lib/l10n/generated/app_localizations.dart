import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @accountAuthCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the sign-in code we just sent you.'**
  String get accountAuthCodeBody;

  /// No description provided for @accountAuthCodeCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get accountAuthCodeCta;

  /// No description provided for @accountAuthCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get accountAuthCodeLabel;

  /// No description provided for @accountAuthCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent — check your email.'**
  String get accountAuthCodeSent;

  /// No description provided for @accountAuthCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get accountAuthCodeTitle;

  /// No description provided for @accountAuthContinueWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get accountAuthContinueWithoutAccount;

  /// No description provided for @accountAuthCreateBody.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. Create an account to restore access later.'**
  String get accountAuthCreateBody;

  /// No description provided for @accountAuthCreateCta.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountAuthCreateCta;

  /// No description provided for @accountAuthCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your ArchiveMe account'**
  String get accountAuthCreateTitle;

  /// No description provided for @accountAuthEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountAuthEmailLabel;

  /// No description provided for @accountAuthInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email.'**
  String get accountAuthInvalidCode;

  /// No description provided for @accountAuthInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountAuthInvalidEmail;

  /// No description provided for @accountAuthPrivacyLine.
  ///
  /// In en, this message translates to:
  /// **'Your archive stays private. We do not include your recordings in analytics.'**
  String get accountAuthPrivacyLine;

  /// No description provided for @accountAuthResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get accountAuthResendCode;

  /// No description provided for @accountAuthSendCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the code.'**
  String get accountAuthSendCodeFailed;

  /// No description provided for @accountAuthSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountAuthSignInCta;

  /// No description provided for @accountAuthSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check the code and try again.'**
  String get accountAuthSignInFailed;

  /// No description provided for @accountAuthSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to ArchiveMe'**
  String get accountAuthSignInTitle;

  /// No description provided for @accountAuthSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountAuthSignOut;

  /// No description provided for @accountAuthSignOutKeepsArchive.
  ///
  /// In en, this message translates to:
  /// **'Signing out keeps your recordings on this device.'**
  String get accountAuthSignOutKeepsArchive;

  /// No description provided for @accountAuthTimingNote.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. You can use it locally without an account.'**
  String get accountAuthTimingNote;

  /// No description provided for @accountScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Account screen'**
  String get accountScreenLabel;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe'**
  String get appTitle;

  /// No description provided for @archiveAddMoment.
  ///
  /// In en, this message translates to:
  /// **'Add a moment'**
  String get archiveAddMoment;

  /// No description provided for @archiveCurrentObservation.
  ///
  /// In en, this message translates to:
  /// **'Your clearest current observation is: {statement}'**
  String archiveCurrentObservation(String statement);

  /// No description provided for @archiveEvidenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 saved moment available for comparison.} other{{count} saved moments available for comparison.}}'**
  String archiveEvidenceCount(int count);

  /// No description provided for @archiveEvidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get archiveEvidenceTitle;

  /// No description provided for @archiveNeedsComparison.
  ///
  /// In en, this message translates to:
  /// **'Add another moment so ArchiveMe can compare what changed.'**
  String get archiveNeedsComparison;

  /// No description provided for @archiveNeedsSupportedMoments.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe needs at least two supported moments before explaining a pattern.'**
  String get archiveNeedsSupportedMoments;

  /// No description provided for @archiveNextMomentGuidance.
  ///
  /// In en, this message translates to:
  /// **'Record or type one specific moment. A second supported observation makes change visible.'**
  String get archiveNextMomentGuidance;

  /// No description provided for @archiveNextStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get archiveNextStepsTitle;

  /// No description provided for @archiveScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive screen'**
  String get archiveScreenLabel;

  /// No description provided for @archiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archiveTitle;

  /// No description provided for @archiveWhatChangedTitle.
  ///
  /// In en, this message translates to:
  /// **'What changed?'**
  String get archiveWhatChangedTitle;

  /// No description provided for @archiveWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why?'**
  String get archiveWhyTitle;

  /// No description provided for @authTriggerArchiveChangedReturnCta.
  ///
  /// In en, this message translates to:
  /// **'Protect archive'**
  String get authTriggerArchiveChangedReturnCta;

  /// No description provided for @authTriggerArchiveChangedReturnLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to protect your archive after it may have shifted.'**
  String get authTriggerArchiveChangedReturnLead;

  /// No description provided for @authTriggerArchiveChangedReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'See what your archive believes now'**
  String get authTriggerArchiveChangedReturnTitle;

  /// No description provided for @authTriggerCrossDeviceCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authTriggerCrossDeviceCta;

  /// No description provided for @authTriggerCrossDeviceLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pick up your archive where you left off.'**
  String get authTriggerCrossDeviceLead;

  /// No description provided for @authTriggerCrossDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue on another device'**
  String get authTriggerCrossDeviceTitle;

  /// No description provided for @authTriggerExportCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to export'**
  String get authTriggerExportCta;

  /// No description provided for @authTriggerExportLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in before exporting your archive.'**
  String get authTriggerExportLead;

  /// No description provided for @authTriggerExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export with a protected account'**
  String get authTriggerExportTitle;

  /// No description provided for @authTriggerFirstWorkingBeliefCta.
  ///
  /// In en, this message translates to:
  /// **'Protect this belief'**
  String get authTriggerFirstWorkingBeliefCta;

  /// No description provided for @authTriggerFirstWorkingBeliefLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to protect the belief your archive is forming.'**
  String get authTriggerFirstWorkingBeliefLead;

  /// No description provided for @authTriggerFirstWorkingBeliefTitle.
  ///
  /// In en, this message translates to:
  /// **'Your archive has a working belief'**
  String get authTriggerFirstWorkingBeliefTitle;

  /// No description provided for @authTriggerKeepTrackingProCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authTriggerKeepTrackingProCta;

  /// No description provided for @authTriggerKeepTrackingProLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in before upgrading so your archive stays backed up.'**
  String get authTriggerKeepTrackingProLead;

  /// No description provided for @authTriggerKeepTrackingProTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep tracking with Pro'**
  String get authTriggerKeepTrackingProTitle;

  /// No description provided for @authTriggerProPaywallCta.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authTriggerProPaywallCta;

  /// No description provided for @authTriggerProPaywallLead.
  ///
  /// In en, this message translates to:
  /// **'Checkout needs an account to protect your archive.'**
  String get authTriggerProPaywallLead;

  /// No description provided for @authTriggerProPaywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in for Pro'**
  String get authTriggerProPaywallTitle;

  /// No description provided for @authTriggerProtectArchiveCta.
  ///
  /// In en, this message translates to:
  /// **'Protect with email'**
  String get authTriggerProtectArchiveCta;

  /// No description provided for @authTriggerProtectArchiveLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email to encrypt a backup of what you built on this device.'**
  String get authTriggerProtectArchiveLead;

  /// No description provided for @authTriggerProtectArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect this archive'**
  String get authTriggerProtectArchiveTitle;

  /// No description provided for @authTriggerSyncArchiveCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get authTriggerSyncArchiveCta;

  /// No description provided for @authTriggerSyncArchiveLead.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in enables encrypted sync on this device.'**
  String get authTriggerSyncArchiveLead;

  /// No description provided for @authTriggerSyncArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your archive'**
  String get authTriggerSyncArchiveTitle;

  /// No description provided for @changesScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Changes screen'**
  String get changesScreenLabel;

  /// No description provided for @coachingConfidence.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% confidence'**
  String coachingConfidence(int percentage);

  /// No description provided for @coachingConfidenceSemantics.
  ///
  /// In en, this message translates to:
  /// **'Confidence {percentage} percent'**
  String coachingConfidenceSemantics(int percentage);

  /// No description provided for @coachingInsightHint.
  ///
  /// In en, this message translates to:
  /// **'AI-generated reflection based on recent journal evidence.'**
  String get coachingInsightHint;

  /// No description provided for @coachingInsightSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}. Confidence {percentage} percent. {content}'**
  String coachingInsightSemantics(
    String category,
    int percentage,
    String content,
  );

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @dataPortabilityTrustFooter.
  ///
  /// In en, this message translates to:
  /// **'Exported from your device. Your own voice — not therapy or diagnosis.'**
  String get dataPortabilityTrustFooter;

  /// No description provided for @exportJsonCta.
  ///
  /// In en, this message translates to:
  /// **'Export JSON'**
  String get exportJsonCta;

  /// No description provided for @exportPortabilityBusy.
  ///
  /// In en, this message translates to:
  /// **'Building export…'**
  String get exportPortabilityBusy;

  /// No description provided for @exportPortabilityCta.
  ///
  /// In en, this message translates to:
  /// **'Download full archive (ZIP)'**
  String get exportPortabilityCta;

  /// No description provided for @exportPortabilityFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed. Try again.'**
  String get exportPortabilityFailed;

  /// No description provided for @exportPortabilitySuccess.
  ///
  /// In en, this message translates to:
  /// **'Export ready — share or save the ZIP file.'**
  String get exportPortabilitySuccess;

  /// No description provided for @exportScreenLead.
  ///
  /// In en, this message translates to:
  /// **'Download a portable copy of your archive for backup or migration.'**
  String get exportScreenLead;

  /// No description provided for @exportScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportScreenTitle;

  /// No description provided for @memoryGraphActionBarHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe horizontally to explore more graph actions.'**
  String get memoryGraphActionBarHint;

  /// No description provided for @memoryGraphActionBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory Graph actions'**
  String get memoryGraphActionBarLabel;

  /// No description provided for @memoryGraphActionButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to activate this graph action.'**
  String get memoryGraphActionButtonHint;

  /// No description provided for @memoryGraphClosePreview.
  ///
  /// In en, this message translates to:
  /// **'Close Preview'**
  String get memoryGraphClosePreview;

  /// No description provided for @memoryGraphCloseRewind.
  ///
  /// In en, this message translates to:
  /// **'Close Rewind'**
  String get memoryGraphCloseRewind;

  /// No description provided for @memoryGraphClusters.
  ///
  /// In en, this message translates to:
  /// **'Clusters {count}'**
  String memoryGraphClusters(int count);

  /// No description provided for @memoryGraphDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get memoryGraphDocuments;

  /// No description provided for @memoryGraphLifeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Life Dashboard'**
  String get memoryGraphLifeDashboard;

  /// No description provided for @memoryGraphLifeSimulator.
  ///
  /// In en, this message translates to:
  /// **'Life Simulator'**
  String get memoryGraphLifeSimulator;

  /// No description provided for @memoryGraphNodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 node} other{{count} nodes}}'**
  String memoryGraphNodeCount(int count);

  /// No description provided for @memoryGraphPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview Graph'**
  String get memoryGraphPreview;

  /// No description provided for @memoryGraphReturnToPresent.
  ///
  /// In en, this message translates to:
  /// **'Return to Present'**
  String get memoryGraphReturnToPresent;

  /// No description provided for @memoryGraphSampleBadge.
  ///
  /// In en, this message translates to:
  /// **'Sample Mind · illustrative'**
  String get memoryGraphSampleBadge;

  /// No description provided for @memoryGraphSmallSteps.
  ///
  /// In en, this message translates to:
  /// **'Small steps'**
  String get memoryGraphSmallSteps;

  /// No description provided for @memoryGraphTimeMachine.
  ///
  /// In en, this message translates to:
  /// **'Time Machine'**
  String get memoryGraphTimeMachine;

  /// No description provided for @memoryGraphWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get memoryGraphWeekly;

  /// No description provided for @memoryGraphWidgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get memoryGraphWidgets;

  /// No description provided for @meshNoPeers.
  ///
  /// In en, this message translates to:
  /// **'No paired devices are nearby.'**
  String get meshNoPeers;

  /// No description provided for @meshPairDevice.
  ///
  /// In en, this message translates to:
  /// **'Pair a device'**
  String get meshPairDevice;

  /// No description provided for @meshPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Nearby discovery advertises only a rotating identifier. Archive metadata is exchanged after encrypted pairing.'**
  String get meshPrivacyDescription;

  /// No description provided for @meshReadOnlyBranch.
  ///
  /// In en, this message translates to:
  /// **'Read-only shared branch'**
  String get meshReadOnlyBranch;

  /// No description provided for @meshShareCluster.
  ///
  /// In en, this message translates to:
  /// **'Share this cluster'**
  String get meshShareCluster;

  /// No description provided for @meshStatusComplete.
  ///
  /// In en, this message translates to:
  /// **'Local sync complete'**
  String get meshStatusComplete;

  /// No description provided for @meshStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected securely'**
  String get meshStatusConnected;

  /// No description provided for @meshStatusSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching nearby'**
  String get meshStatusSearching;

  /// No description provided for @meshStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby encrypted sync'**
  String get meshStatusTitle;

  /// No description provided for @meshSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync nearby'**
  String get meshSyncNow;

  /// No description provided for @navigationAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navigationAccount;

  /// No description provided for @navigationArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get navigationArchive;

  /// No description provided for @navigationChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get navigationChanges;

  /// No description provided for @navigationRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navigationRecord;

  /// No description provided for @primaryNavigationLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary navigation'**
  String get primaryNavigationLabel;

  /// No description provided for @recapCopied.
  ///
  /// In en, this message translates to:
  /// **'Recap copied.'**
  String get recapCopied;

  /// No description provided for @recordScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Record screen'**
  String get recordScreenLabel;

  /// No description provided for @recordingCopyRecap.
  ///
  /// In en, this message translates to:
  /// **'Copy recap'**
  String get recordingCopyRecap;

  /// No description provided for @recordingEnoughForNow.
  ///
  /// In en, this message translates to:
  /// **'That\'s enough for now'**
  String get recordingEnoughForNow;

  /// No description provided for @recordingInProgressSeconds.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress, {seconds, plural, one{1 second} other{{seconds} seconds}}'**
  String recordingInProgressSeconds(int seconds);

  /// No description provided for @recordingPlainLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Say it plainly. ArchiveMe looks for patterns, not judgment.'**
  String get recordingPlainLanguageHint;

  /// No description provided for @recordingProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordingProcessingStatus;

  /// No description provided for @recordingPromptNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe uses what you record to surface sharper things worth checking each day.'**
  String get recordingPromptNudgeBody;

  /// No description provided for @recordingPromptNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your daily archive prompts improving'**
  String get recordingPromptNudgeTitle;

  /// No description provided for @recordingReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get recordingReadyStatus;

  /// No description provided for @recordingSavedBackgroundTranscription.
  ///
  /// In en, this message translates to:
  /// **'Recording saved. Transcription will finish in the background.'**
  String get recordingSavedBackgroundTranscription;

  /// No description provided for @recordingSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get recordingSavedStatus;

  /// No description provided for @recordingStatus.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingStatus;

  /// No description provided for @recordingStopAndSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Stop and save when you are finished.'**
  String get recordingStopAndSaveHint;

  /// No description provided for @recordingUnlockPro.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get recordingUnlockPro;

  /// No description provided for @savedForNextCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Saved for your next check-in.'**
  String get savedForNextCheckIn;

  /// No description provided for @savedForNextMonthCheck.
  ///
  /// In en, this message translates to:
  /// **'Saved for next month\'s check.'**
  String get savedForNextMonthCheck;

  /// No description provided for @savedForTomorrowCheck.
  ///
  /// In en, this message translates to:
  /// **'Saved for tomorrow\'s check.'**
  String get savedForTomorrowCheck;

  /// No description provided for @textJournalPanelLead.
  ///
  /// In en, this message translates to:
  /// **'No microphone needed — a few sentences is enough for your archive.'**
  String get textJournalPanelLead;

  /// No description provided for @textJournalPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Type a moment'**
  String get textJournalPanelTitle;

  /// No description provided for @textJournalSaveCta.
  ///
  /// In en, this message translates to:
  /// **'Save thought'**
  String get textJournalSaveCta;

  /// No description provided for @tomorrowCheckSet.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s check is set.'**
  String get tomorrowCheckSet;

  /// No description provided for @watchQuickRecordCta.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get watchQuickRecordCta;

  /// No description provided for @watchQuickRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick record'**
  String get watchQuickRecordTitle;

  /// No description provided for @widgetQuickCaptureAction.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get widgetQuickCaptureAction;

  /// No description provided for @widgetQuickCaptureBody.
  ///
  /// In en, this message translates to:
  /// **'Capture a moment from your home screen.'**
  String get widgetQuickCaptureBody;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe account'**
  String get accountTitle;

  /// No description provided for @syncStatus.
  ///
  /// In en, this message translates to:
  /// **'Sync status'**
  String get syncStatus;

  /// No description provided for @syncNotAvailableTestFlight.
  ///
  /// In en, this message translates to:
  /// **'Sync is not available in this TestFlight build.'**
  String get syncNotAvailableTestFlight;

  /// No description provided for @syncOnDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On this device'**
  String get syncOnDeviceOnly;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @accountPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your recordings stay on this device unless you sign in to sync.'**
  String get accountPrivacyNote;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountSessionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get accountSessionLoading;

  /// No description provided for @accountNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get accountNotSignedIn;

  /// No description provided for @accountSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get accountSignedIn;

  /// No description provided for @accountSignedInForSync.
  ///
  /// In en, this message translates to:
  /// **'Signed in for sync'**
  String get accountSignedInForSync;

  /// No description provided for @accountLastSyncedToday.
  ///
  /// In en, this message translates to:
  /// **'Last synced today'**
  String get accountLastSyncedToday;

  /// No description provided for @recordTitle.
  ///
  /// In en, this message translates to:
  /// **'What is on your mind?'**
  String get recordTitle;

  /// No description provided for @recordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Say one small thing from today.'**
  String get recordSubtitle;

  /// No description provided for @recordOneMomentCta.
  ///
  /// In en, this message translates to:
  /// **'Record one moment'**
  String get recordOneMomentCta;

  /// No description provided for @recordMomentCta.
  ///
  /// In en, this message translates to:
  /// **'Record moment'**
  String get recordMomentCta;

  /// No description provided for @stopRecordingCta.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecordingCta;

  /// No description provided for @recordAnotherCta.
  ///
  /// In en, this message translates to:
  /// **'Record another'**
  String get recordAnotherCta;

  /// No description provided for @recordNextMomentCta.
  ///
  /// In en, this message translates to:
  /// **'Record next moment'**
  String get recordNextMomentCta;

  /// No description provided for @startRecording.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get startRecording;

  /// No description provided for @trySayingOneOfThese.
  ///
  /// In en, this message translates to:
  /// **'Try saying one of these'**
  String get trySayingOneOfThese;

  /// No description provided for @recordHelpSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a prompt'**
  String get recordHelpSheetTitle;

  /// No description provided for @recordHelpSheetHelper.
  ///
  /// In en, this message translates to:
  /// **'Choose one, then record one sentence.'**
  String get recordHelpSheetHelper;

  /// No description provided for @reflectionSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Reflection saved'**
  String get reflectionSavedTitle;

  /// No description provided for @postSaveRecordAnother.
  ///
  /// In en, this message translates to:
  /// **'Record another moment'**
  String get postSaveRecordAnother;

  /// No description provided for @viewPatternsCta.
  ///
  /// In en, this message translates to:
  /// **'View patterns'**
  String get viewPatternsCta;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @firstSavePostSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved.'**
  String get firstSavePostSaveTitle;

  /// No description provided for @firstSavePostSaveBody.
  ///
  /// In en, this message translates to:
  /// **'Come back when this shows up again.'**
  String get firstSavePostSaveBody;

  /// No description provided for @finishRecordingFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish or cancel the recording first.'**
  String get finishRecordingFirst;

  /// No description provided for @paywallHeadline.
  ///
  /// In en, this message translates to:
  /// **'You saw the first useful repeat.'**
  String get paywallHeadline;

  /// No description provided for @paywallSubhead.
  ///
  /// In en, this message translates to:
  /// **'Free shows the first useful proof. Pro keeps the longer trail.'**
  String get paywallSubhead;

  /// No description provided for @paywallPrimaryCta.
  ///
  /// In en, this message translates to:
  /// **'Keep the longer trail'**
  String get paywallPrimaryCta;

  /// No description provided for @paywallSecondaryCta.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get paywallSecondaryCta;

  /// No description provided for @paywallContinue.
  ///
  /// In en, this message translates to:
  /// **'Keep the longer trail'**
  String get paywallContinue;

  /// No description provided for @paywallDifferentiation.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe is not trying to answer better than ChatGPT. It is trying to remember differently.'**
  String get paywallDifferentiation;

  /// No description provided for @paywallTrust.
  ///
  /// In en, this message translates to:
  /// **'Your saves stay free. Manage or cancel anytime in the App Store.'**
  String get paywallTrust;

  /// No description provided for @paywallBackupLine.
  ///
  /// In en, this message translates to:
  /// **'You are building evidence over time. Pro keeps the longer proof trail as moments return, change, or fade.'**
  String get paywallBackupLine;

  /// No description provided for @paywallPrimaryValueBlock.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps a longer private archive — more moments, more continuity, more evidence over time.'**
  String get paywallPrimaryValueBlock;

  /// No description provided for @paywallBackToPatterns.
  ///
  /// In en, this message translates to:
  /// **'Back to Patterns'**
  String get paywallBackToPatterns;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get restorePurchases;

  /// No description provided for @paywallAnchorPositioningLine.
  ///
  /// In en, this message translates to:
  /// **'Keep your verified timeline growing.'**
  String get paywallAnchorPositioningLine;

  /// No description provided for @paywallProofConnectedLine.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps a longer private archive — more moments, more continuity, more evidence over time.'**
  String get paywallProofConnectedLine;

  /// No description provided for @paywallSecondaryReassurance.
  ///
  /// In en, this message translates to:
  /// **'You stay in control. You can delete entries and correct what you saved.'**
  String get paywallSecondaryReassurance;

  /// No description provided for @paywallBenefitBullet1.
  ///
  /// In en, this message translates to:
  /// **'Longer evidence history on this device'**
  String get paywallBenefitBullet1;

  /// No description provided for @paywallBenefitBullet2.
  ///
  /// In en, this message translates to:
  /// **'More archived moments over weeks and months'**
  String get paywallBenefitBullet2;

  /// No description provided for @paywallBenefitBullet3.
  ///
  /// In en, this message translates to:
  /// **'Continuity when patterns return or change'**
  String get paywallBenefitBullet3;

  /// No description provided for @paywallSetupUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Plans are not available right now.'**
  String get paywallSetupUnavailableBody;

  /// No description provided for @paywallUnavailablePlansLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading plans…'**
  String get paywallUnavailablePlansLoading;

  /// No description provided for @valueMomentProTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the longer proof trail'**
  String get valueMomentProTitle;

  /// No description provided for @valueMomentProCta.
  ///
  /// In en, this message translates to:
  /// **'See Pro'**
  String get valueMomentProCta;

  /// No description provided for @valueMomentProDismiss.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get valueMomentProDismiss;

  /// No description provided for @valueMomentThreadReturnBody.
  ///
  /// In en, this message translates to:
  /// **'This thread has returned before. Pro keeps the evidence history so ArchiveMe can show whether it gets stronger, softer, or changes.'**
  String get valueMomentThreadReturnBody;

  /// No description provided for @valueMomentBeliefBody.
  ///
  /// In en, this message translates to:
  /// **'A belief-like phrase showed up again. Pro keeps the timeline of what changed across your archive.'**
  String get valueMomentBeliefBody;

  /// No description provided for @valueMomentWeeklyBody.
  ///
  /// In en, this message translates to:
  /// **'Your weekly review found something to compare. Pro keeps weekly archive reviews so ArchiveMe can track what changed over time.'**
  String get valueMomentWeeklyBody;

  /// No description provided for @valueMomentProofCounterBody.
  ///
  /// In en, this message translates to:
  /// **'Your archive has connected recordings. Pro keeps the full evidence history as the trail grows.'**
  String get valueMomentProofCounterBody;

  /// No description provided for @valueMomentFallbackBody.
  ///
  /// In en, this message translates to:
  /// **'Your first repeat is free. Pro keeps the evidence history so ArchiveMe can show whether patterns get stronger, softer, or change over time.'**
  String get valueMomentFallbackBody;

  /// No description provided for @subscriptionPaywallNoOfferings.
  ///
  /// In en, this message translates to:
  /// **'No subscription plans are available.'**
  String get subscriptionPaywallNoOfferings;

  /// No description provided for @purchaseSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pro is active.'**
  String get purchaseSuccess;

  /// No description provided for @restorePurchasesError.
  ///
  /// In en, this message translates to:
  /// **'Could not restore purchases.'**
  String get restorePurchasesError;

  /// No description provided for @patternsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get patternsTabLabel;

  /// No description provided for @patternsEmptyPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Record a few real moments'**
  String get patternsEmptyPageTitle;

  /// No description provided for @patternsEarlyStateBody.
  ///
  /// In en, this message translates to:
  /// **'Record a few real moments. ArchiveMe will look for what repeats across them.'**
  String get patternsEarlyStateBody;

  /// No description provided for @patternsEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Record moment'**
  String get patternsEmptyCta;

  /// No description provided for @patternsHeroHeading.
  ///
  /// In en, this message translates to:
  /// **'WHAT KEEPS REPEATING IN YOUR LIFE'**
  String get patternsHeroHeading;

  /// No description provided for @patternsShiftingHeading.
  ///
  /// In en, this message translates to:
  /// **'WHAT MAY BE CHANGING'**
  String get patternsShiftingHeading;

  /// No description provided for @patternsEvolutionHeading.
  ///
  /// In en, this message translates to:
  /// **'CHANGING OVER TIME'**
  String get patternsEvolutionHeading;

  /// No description provided for @patternsSectionCurrent.
  ///
  /// In en, this message translates to:
  /// **'Patterns that keep repeating'**
  String get patternsSectionCurrent;

  /// No description provided for @patternsSectionEmerging.
  ///
  /// In en, this message translates to:
  /// **'A pattern is forming'**
  String get patternsSectionEmerging;

  /// No description provided for @patternsSectionChanging.
  ///
  /// In en, this message translates to:
  /// **'This seems to be changing'**
  String get patternsSectionChanging;

  /// No description provided for @patternsFirstEntrySavedTitle.
  ///
  /// In en, this message translates to:
  /// **'First moment saved'**
  String get patternsFirstEntrySavedTitle;

  /// No description provided for @patternsFirstEntrySavedBody.
  ///
  /// In en, this message translates to:
  /// **'Record one more clear moment and ArchiveMe can compare what repeats.'**
  String get patternsFirstEntrySavedBody;

  /// No description provided for @patternsFirstEntrySavedCta.
  ///
  /// In en, this message translates to:
  /// **'Record another moment'**
  String get patternsFirstEntrySavedCta;

  /// No description provided for @patternsFirstEntryViewSavedCta.
  ///
  /// In en, this message translates to:
  /// **'View saved entry'**
  String get patternsFirstEntryViewSavedCta;

  /// No description provided for @patternsHowItWorksTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get patternsHowItWorksTitle;

  /// No description provided for @patternsPrivacyReassurance.
  ///
  /// In en, this message translates to:
  /// **'Private on your device. Nothing is shared without you choosing to.'**
  String get patternsPrivacyReassurance;

  /// No description provided for @allPatternsTitle.
  ///
  /// In en, this message translates to:
  /// **'All patterns'**
  String get allPatternsTitle;

  /// No description provided for @allPatternsLead.
  ///
  /// In en, this message translates to:
  /// **'Patterns and themes ArchiveMe keeps noticing in your reflections.'**
  String get allPatternsLead;

  /// No description provided for @patternsCheckInWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in waiting'**
  String get patternsCheckInWaitingTitle;

  /// No description provided for @patternsCheckInWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe has a question from your last moment.'**
  String get patternsCheckInWaitingBody;

  /// No description provided for @patternsCheckInWaitingCta.
  ///
  /// In en, this message translates to:
  /// **'Answer it now'**
  String get patternsCheckInWaitingCta;

  /// No description provided for @patternsLoopClosedTitle.
  ///
  /// In en, this message translates to:
  /// **'Loop closed'**
  String get patternsLoopClosedTitle;

  /// No description provided for @patternsRecordAnotherMomentCta.
  ///
  /// In en, this message translates to:
  /// **'Record another moment'**
  String get patternsRecordAnotherMomentCta;

  /// No description provided for @patternsResultUseCheckCta.
  ///
  /// In en, this message translates to:
  /// **'Use this check'**
  String get patternsResultUseCheckCta;

  /// No description provided for @patternsSignalsWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Signals waiting for clarity'**
  String get patternsSignalsWaitingTitle;

  /// No description provided for @patternsWatchingSignalTitle.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe is watching this signal'**
  String get patternsWatchingSignalTitle;

  /// No description provided for @patternsWatchingSignalBody.
  ///
  /// In en, this message translates to:
  /// **'Record one more moment to test whether it repeats.'**
  String get patternsWatchingSignalBody;

  /// No description provided for @archiveDiscoverPatternsLink.
  ///
  /// In en, this message translates to:
  /// **'See all patterns'**
  String get archiveDiscoverPatternsLink;

  /// No description provided for @archiveTimelineLink.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get archiveTimelineLink;

  /// No description provided for @archiveSearchLink.
  ///
  /// In en, this message translates to:
  /// **'Search archive'**
  String get archiveSearchLink;

  /// No description provided for @activePatternCurrentTitle.
  ///
  /// In en, this message translates to:
  /// **'Current pattern'**
  String get activePatternCurrentTitle;

  /// No description provided for @activePatternRecordTodayCta.
  ///
  /// In en, this message translates to:
  /// **'Record today'**
  String get activePatternRecordTodayCta;

  /// No description provided for @seeWhatChanged.
  ///
  /// In en, this message translates to:
  /// **'See what changed'**
  String get seeWhatChanged;

  /// No description provided for @patternsComeBackTitle.
  ///
  /// In en, this message translates to:
  /// **'Why come back tomorrow?'**
  String get patternsComeBackTitle;

  /// No description provided for @patternsComeBackBody.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe compares what you save over time.'**
  String get patternsComeBackBody;

  /// No description provided for @patternsComeBackRecordCta.
  ///
  /// In en, this message translates to:
  /// **'Record today\'s reflection'**
  String get patternsComeBackRecordCta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
