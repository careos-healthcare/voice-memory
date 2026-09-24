import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ms.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_zh.dart';

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
    Locale('hi'),
    Locale('ms'),
    Locale('ta'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
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
  /// **'Thoughtprint is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. Create an account to restore access later.'**
  String get accountAuthCreateBody;

  /// No description provided for @accountAuthCreateCta.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountAuthCreateCta;

  /// No description provided for @accountAuthCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your Thoughtprint account'**
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
  /// **'Sign in to Thoughtprint'**
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
  /// **'Thoughtprint is a private voice journal that turns your spoken thoughts into a unified life story and deep personal intelligence. You can use it locally without an account.'**
  String get accountAuthTimingNote;

  /// No description provided for @accountScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Account screen'**
  String get accountScreenLabel;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint'**
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
  /// **'Add another moment so Thoughtprint can compare what changed.'**
  String get archiveNeedsComparison;

  /// No description provided for @archiveNeedsSupportedMoments.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs at least two supported moments before explaining a pattern.'**
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
  /// **'Say it plainly. Thoughtprint looks for patterns, not judgment.'**
  String get recordingPlainLanguageHint;

  /// No description provided for @recordingProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordingProcessingStatus;

  /// No description provided for @recordingPromptNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint uses what you record to surface sharper things worth checking each day.'**
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
  /// **'Thoughtprint account'**
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
  /// **'Thoughtprint is not trying to answer better than ChatGPT. It is trying to remember differently.'**
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
  /// **'This thread has returned before. Pro keeps the evidence history so Thoughtprint can show whether it gets stronger, softer, or changes.'**
  String get valueMomentThreadReturnBody;

  /// No description provided for @valueMomentBeliefBody.
  ///
  /// In en, this message translates to:
  /// **'A belief-like phrase showed up again. Pro keeps the timeline of what changed across your archive.'**
  String get valueMomentBeliefBody;

  /// No description provided for @valueMomentWeeklyBody.
  ///
  /// In en, this message translates to:
  /// **'Your weekly review found something to compare. Pro keeps weekly archive reviews so Thoughtprint can track what changed over time.'**
  String get valueMomentWeeklyBody;

  /// No description provided for @valueMomentProofCounterBody.
  ///
  /// In en, this message translates to:
  /// **'Your archive has connected recordings. Pro keeps the full evidence history as the trail grows.'**
  String get valueMomentProofCounterBody;

  /// No description provided for @valueMomentFallbackBody.
  ///
  /// In en, this message translates to:
  /// **'Your first repeat is free. Pro keeps the evidence history so Thoughtprint can show whether patterns get stronger, softer, or change over time.'**
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
  /// **'Record a few real moments. Thoughtprint will look for what repeats across them.'**
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
  /// **'Record one more clear moment and Thoughtprint can compare what repeats.'**
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
  /// **'Patterns and themes Thoughtprint keeps noticing in your reflections.'**
  String get allPatternsLead;

  /// No description provided for @patternsCheckInWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Check-in waiting'**
  String get patternsCheckInWaitingTitle;

  /// No description provided for @patternsCheckInWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has a question from your last moment.'**
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
  /// **'Thoughtprint is watching this signal'**
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
  /// **'Thoughtprint compares what you save over time.'**
  String get patternsComeBackBody;

  /// No description provided for @patternsComeBackRecordCta.
  ///
  /// In en, this message translates to:
  /// **'Record today\'s reflection'**
  String get patternsComeBackRecordCta;

  /// No description provided for @v1Copy0000.
  ///
  /// In en, this message translates to:
  /// **'When it repeats, record it.'**
  String get v1Copy0000;

  /// No description provided for @v1Copy0001.
  ///
  /// In en, this message translates to:
  /// **'Record one real entry. Thoughtprint compares it later.'**
  String get v1Copy0001;

  /// No description provided for @v1Copy0002.
  ///
  /// In en, this message translates to:
  /// **'Not a diary. Not homework. One sentence is enough.'**
  String get v1Copy0002;

  /// No description provided for @v1Copy0003.
  ///
  /// In en, this message translates to:
  /// **'When something shows up again, your archive builds an evidence trail.'**
  String get v1Copy0003;

  /// No description provided for @v1Copy0004.
  ///
  /// In en, this message translates to:
  /// **'Over time, it can show what started it, what changed, and what helped.'**
  String get v1Copy0004;

  /// No description provided for @v1Copy0005.
  ///
  /// In en, this message translates to:
  /// **'Type instead'**
  String get v1Copy0005;

  /// No description provided for @v1Copy0006.
  ///
  /// In en, this message translates to:
  /// **'Record entry'**
  String get v1Copy0006;

  /// No description provided for @v1Copy0007.
  ///
  /// In en, this message translates to:
  /// **'How Thoughtprint works'**
  String get v1Copy0007;

  /// No description provided for @v1Copy0009.
  ///
  /// In en, this message translates to:
  /// **'What returned'**
  String get v1Copy0009;

  /// No description provided for @v1Copy0010.
  ///
  /// In en, this message translates to:
  /// **'What softened'**
  String get v1Copy0010;

  /// No description provided for @v1Copy0011.
  ///
  /// In en, this message translates to:
  /// **'What changed'**
  String get v1Copy0011;

  /// No description provided for @v1Copy0013.
  ///
  /// In en, this message translates to:
  /// **'If it returns, changes, fades, or disappears, record that entry too. '**
  String get v1Copy0013;

  /// No description provided for @v1Copy0014.
  ///
  /// In en, this message translates to:
  /// **'You do not need to keep working on this now.'**
  String get v1Copy0014;

  /// No description provided for @v1Copy0015.
  ///
  /// In en, this message translates to:
  /// **'Done for today'**
  String get v1Copy0015;

  /// No description provided for @v1Copy0016.
  ///
  /// In en, this message translates to:
  /// **'This may be a repeat:'**
  String get v1Copy0016;

  /// No description provided for @v1Copy0017.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can now start comparing this pattern.'**
  String get v1Copy0017;

  /// No description provided for @v1Copy0018.
  ///
  /// In en, this message translates to:
  /// **'This looks like it came back.'**
  String get v1Copy0018;

  /// No description provided for @v1Copy0019.
  ///
  /// In en, this message translates to:
  /// **'You mentioned something similar before.'**
  String get v1Copy0019;

  /// No description provided for @v1Copy0020.
  ///
  /// In en, this message translates to:
  /// **'This may be the same pattern as an earlier recorded entry.'**
  String get v1Copy0020;

  /// No description provided for @v1Copy0021.
  ///
  /// In en, this message translates to:
  /// **'This looks like it came back, but Thoughtprint needs more entries to be sure.'**
  String get v1Copy0021;

  /// No description provided for @v1Copy0024.
  ///
  /// In en, this message translates to:
  /// **'Why this matters'**
  String get v1Copy0024;

  /// No description provided for @v1Copy0025.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps the longer trail.'**
  String get v1Copy0025;

  /// No description provided for @v1Copy0026.
  ///
  /// In en, this message translates to:
  /// **'Your archive has started.'**
  String get v1Copy0026;

  /// No description provided for @v1Copy0027.
  ///
  /// In en, this message translates to:
  /// **'This is the first piece of evidence.'**
  String get v1Copy0027;

  /// No description provided for @v1Copy0028.
  ///
  /// In en, this message translates to:
  /// **'If it returns, changes, fades, or disappears, record that entry too.'**
  String get v1Copy0028;

  /// No description provided for @v1Copy0029.
  ///
  /// In en, this message translates to:
  /// **'Come back when this shows up again. Just one private record so far.'**
  String get v1Copy0029;

  /// No description provided for @v1Copy0030.
  ///
  /// In en, this message translates to:
  /// **'Sample Archive below shows how comparison works — demo entries only, '**
  String get v1Copy0030;

  /// No description provided for @v1Copy0031.
  ///
  /// In en, this message translates to:
  /// **'no private entries.'**
  String get v1Copy0031;

  /// No description provided for @v1Copy0032.
  ///
  /// In en, this message translates to:
  /// **'A second entry lets Thoughtprint compare your own words — cautiously, '**
  String get v1Copy0032;

  /// No description provided for @v1Copy0033.
  ///
  /// In en, this message translates to:
  /// **'not as a conclusion.'**
  String get v1Copy0033;

  /// No description provided for @v1Copy0034.
  ///
  /// In en, this message translates to:
  /// **'Record if it happens again'**
  String get v1Copy0034;

  /// No description provided for @v1Copy0035.
  ///
  /// In en, this message translates to:
  /// **'View archive'**
  String get v1Copy0035;

  /// No description provided for @v1Copy0036.
  ///
  /// In en, this message translates to:
  /// **'Record a few real entries'**
  String get v1Copy0036;

  /// No description provided for @v1Copy0037.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will look for what repeats across them.'**
  String get v1Copy0037;

  /// No description provided for @v1Copy0038.
  ///
  /// In en, this message translates to:
  /// **'What keeps repeating'**
  String get v1Copy0038;

  /// No description provided for @v1Copy0039.
  ///
  /// In en, this message translates to:
  /// **'Next to watch'**
  String get v1Copy0039;

  /// No description provided for @v1Copy0040.
  ///
  /// In en, this message translates to:
  /// **'What may have helped'**
  String get v1Copy0040;

  /// No description provided for @v1Copy0041.
  ///
  /// In en, this message translates to:
  /// **'Patterns are still forming'**
  String get v1Copy0041;

  /// No description provided for @v1Copy0042.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs clearer real entries before it can compare what repeats.'**
  String get v1Copy0042;

  /// No description provided for @v1Copy0043.
  ///
  /// In en, this message translates to:
  /// **'Preview — not a conclusion yet'**
  String get v1Copy0043;

  /// No description provided for @v1Copy0044.
  ///
  /// In en, this message translates to:
  /// **'Not enough evidence yet'**
  String get v1Copy0044;

  /// No description provided for @v1Copy0045.
  ///
  /// In en, this message translates to:
  /// **'Your own words across recordings'**
  String get v1Copy0045;

  /// No description provided for @v1Copy0046.
  ///
  /// In en, this message translates to:
  /// **'Whether the same pattern gets lighter, stronger, or disappears'**
  String get v1Copy0046;

  /// No description provided for @v1Copy0047.
  ///
  /// In en, this message translates to:
  /// **'1 recorded entry'**
  String get v1Copy0047;

  /// No description provided for @v1Copy0048.
  ///
  /// In en, this message translates to:
  /// **'A second entry shows whether the same pattern returns.'**
  String get v1Copy0048;

  /// No description provided for @v1Copy0049.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is starting to compare your entries.'**
  String get v1Copy0049;

  /// No description provided for @v1Copy0050.
  ///
  /// In en, this message translates to:
  /// **'If the same words or situations keep returning, this is where your '**
  String get v1Copy0050;

  /// No description provided for @v1Copy0051.
  ///
  /// In en, this message translates to:
  /// **'archive will show the pattern.'**
  String get v1Copy0051;

  /// No description provided for @v1Copy0052.
  ///
  /// In en, this message translates to:
  /// **'You now have more than one entry to compare.'**
  String get v1Copy0052;

  /// No description provided for @v1Copy0053.
  ///
  /// In en, this message translates to:
  /// **'Record once more to strengthen the signal.'**
  String get v1Copy0053;

  /// No description provided for @v1Copy0054.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has two entries to compare.'**
  String get v1Copy0054;

  /// No description provided for @v1Copy0055.
  ///
  /// In en, this message translates to:
  /// **'No clear repeat yet. One more entry will make the pattern easier to see.'**
  String get v1Copy0055;

  /// No description provided for @v1Copy0056.
  ///
  /// In en, this message translates to:
  /// **'These two entries may be related. Thoughtprint is keeping the evidence '**
  String get v1Copy0056;

  /// No description provided for @v1Copy0057.
  ///
  /// In en, this message translates to:
  /// **'separate until there is more to compare.'**
  String get v1Copy0057;

  /// No description provided for @v1Copy0058.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry to make the pattern clearer.'**
  String get v1Copy0058;

  /// No description provided for @v1Copy0059.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is starting to see a possible pattern.'**
  String get v1Copy0059;

  /// No description provided for @v1Copy0060.
  ///
  /// In en, this message translates to:
  /// **'Still forming — a draft pattern, not a final answer'**
  String get v1Copy0060;

  /// No description provided for @v1Copy0061.
  ///
  /// In en, this message translates to:
  /// **'This is only what your recorded words suggest so far. '**
  String get v1Copy0061;

  /// No description provided for @v1Copy0062.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will keep comparing as you add entries.'**
  String get v1Copy0062;

  /// No description provided for @v1Copy0063.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is using your recorded words, not guessing.'**
  String get v1Copy0063;

  /// No description provided for @v1Copy0064.
  ///
  /// In en, this message translates to:
  /// **'Evidence from your archive'**
  String get v1Copy0064;

  /// No description provided for @v1Copy0065.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can compare this more clearly with one more distinct entry.'**
  String get v1Copy0065;

  /// No description provided for @v1Copy0066.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry to make this clearer.'**
  String get v1Copy0066;

  /// No description provided for @v1Copy0067.
  ///
  /// In en, this message translates to:
  /// **'Your archive noticed something.'**
  String get v1Copy0067;

  /// No description provided for @v1Copy0068.
  ///
  /// In en, this message translates to:
  /// **'Something shifted in your recorded words.'**
  String get v1Copy0068;

  /// No description provided for @v1Copy0069.
  ///
  /// In en, this message translates to:
  /// **'A repeated pattern is starting to stand out.'**
  String get v1Copy0069;

  /// No description provided for @v1Copy0070.
  ///
  /// In en, this message translates to:
  /// **'What this may be pointing to'**
  String get v1Copy0070;

  /// No description provided for @v1Copy0071.
  ///
  /// In en, this message translates to:
  /// **'This showed up in a new context.'**
  String get v1Copy0071;

  /// No description provided for @v1Copy0072.
  ///
  /// In en, this message translates to:
  /// **'The same feeling appeared again, but with different words.'**
  String get v1Copy0072;

  /// No description provided for @v1Copy0073.
  ///
  /// In en, this message translates to:
  /// **'This is appearing in more than one entry, so Thoughtprint can compare '**
  String get v1Copy0073;

  /// No description provided for @v1Copy0074.
  ///
  /// In en, this message translates to:
  /// **'it more clearly.'**
  String get v1Copy0074;

  /// No description provided for @v1Copy0075.
  ///
  /// In en, this message translates to:
  /// **'Your archive is beginning to notice similar pressure across your '**
  String get v1Copy0075;

  /// No description provided for @v1Copy0076.
  ///
  /// In en, this message translates to:
  /// **'recorded entries.'**
  String get v1Copy0076;

  /// No description provided for @v1Copy0077.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to notice pressure around work.'**
  String get v1Copy0077;

  /// No description provided for @v1Copy0078.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to connect pressure with agreeing too quickly.'**
  String get v1Copy0078;

  /// No description provided for @v1Copy0079.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to connect pressure with not falling behind.'**
  String get v1Copy0079;

  /// No description provided for @v1Copy0080.
  ///
  /// In en, this message translates to:
  /// **'View evidence'**
  String get v1Copy0080;

  /// No description provided for @v1Copy0081.
  ///
  /// In en, this message translates to:
  /// **'Evidence behind this possible pattern'**
  String get v1Copy0081;

  /// No description provided for @v1Copy0082.
  ///
  /// In en, this message translates to:
  /// **'This is only what your recorded words suggest so far.'**
  String get v1Copy0082;

  /// No description provided for @v1Copy0083.
  ///
  /// In en, this message translates to:
  /// **'Your archive needs more entries before it can show an evidence trail.'**
  String get v1Copy0083;

  /// No description provided for @v1Copy0084.
  ///
  /// In en, this message translates to:
  /// **'Still uncertain'**
  String get v1Copy0084;

  /// No description provided for @v1Copy0085.
  ///
  /// In en, this message translates to:
  /// **'More distinct recorded entries would make this easier to compare.'**
  String get v1Copy0085;

  /// No description provided for @v1Copy0086.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry'**
  String get v1Copy0086;

  /// No description provided for @v1Copy0087.
  ///
  /// In en, this message translates to:
  /// **'Add one more distinct entry to make this possible pattern clearer.'**
  String get v1Copy0087;

  /// No description provided for @v1Copy0088.
  ///
  /// In en, this message translates to:
  /// **'Add another entry when this shows up again.'**
  String get v1Copy0088;

  /// No description provided for @v1Copy0089.
  ///
  /// In en, this message translates to:
  /// **'A possible pattern in your archive may have changed.'**
  String get v1Copy0089;

  /// No description provided for @v1Copy0090.
  ///
  /// In en, this message translates to:
  /// **'Earlier, your archive was mostly seeing pressure around one entry. '**
  String get v1Copy0090;

  /// No description provided for @v1Copy0091.
  ///
  /// In en, this message translates to:
  /// **'Now it is seeing that pressure across more than one context.'**
  String get v1Copy0091;

  /// No description provided for @v1Copy0092.
  ///
  /// In en, this message translates to:
  /// **'Pattern history'**
  String get v1Copy0092;

  /// No description provided for @v1Copy0093.
  ///
  /// In en, this message translates to:
  /// **'This possible pattern has not clearly changed yet.'**
  String get v1Copy0093;

  /// No description provided for @v1Copy0094.
  ///
  /// In en, this message translates to:
  /// **'Earlier read'**
  String get v1Copy0094;

  /// No description provided for @v1Copy0095.
  ///
  /// In en, this message translates to:
  /// **'Evidence that changed it'**
  String get v1Copy0095;

  /// No description provided for @v1Copy0096.
  ///
  /// In en, this message translates to:
  /// **'Your archive was mostly seeing pressure around one entry.'**
  String get v1Copy0096;

  /// No description provided for @v1Copy0097.
  ///
  /// In en, this message translates to:
  /// **'Your archive appears to see that pressure across more than one context.'**
  String get v1Copy0097;

  /// No description provided for @v1Copy0098.
  ///
  /// In en, this message translates to:
  /// **'A newer entry may have widened what your archive can compare.'**
  String get v1Copy0098;

  /// No description provided for @v1Copy0099.
  ///
  /// In en, this message translates to:
  /// **'Your archive review'**
  String get v1Copy0099;

  /// No description provided for @v1Copy0100.
  ///
  /// In en, this message translates to:
  /// **'What your recorded words are starting to show.'**
  String get v1Copy0100;

  /// No description provided for @v1Copy0101.
  ///
  /// In en, this message translates to:
  /// **'This is a draft pattern, not a final answer.'**
  String get v1Copy0101;

  /// No description provided for @v1Copy0102.
  ///
  /// In en, this message translates to:
  /// **'Your archive needs more entries before it can create a review.'**
  String get v1Copy0102;

  /// No description provided for @v1Copy0103.
  ///
  /// In en, this message translates to:
  /// **'What to add next'**
  String get v1Copy0103;

  /// No description provided for @v1Copy0104.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry when this shows up again.'**
  String get v1Copy0104;

  /// No description provided for @v1Copy0105.
  ///
  /// In en, this message translates to:
  /// **'Add one more distinct entry to make this review clearer.'**
  String get v1Copy0105;

  /// No description provided for @v1Copy0106.
  ///
  /// In en, this message translates to:
  /// **'View review'**
  String get v1Copy0106;

  /// No description provided for @v1Copy0107.
  ///
  /// In en, this message translates to:
  /// **'Pressure at work keeps showing up in your recent entries.'**
  String get v1Copy0107;

  /// No description provided for @v1Copy0108.
  ///
  /// In en, this message translates to:
  /// **'Similar pressure keeps returning in your recent entries.'**
  String get v1Copy0108;

  /// No description provided for @v1Copy0109.
  ///
  /// In en, this message translates to:
  /// **'Saying yes when part of you meant no.'**
  String get v1Copy0109;

  /// No description provided for @v1Copy0110.
  ///
  /// In en, this message translates to:
  /// **'Trying not to fall behind may be doing more of the driving.'**
  String get v1Copy0110;

  /// No description provided for @v1Copy0111.
  ///
  /// In en, this message translates to:
  /// **'Your latest entries may be widening what your archive can compare.'**
  String get v1Copy0111;

  /// No description provided for @v1Copy0112.
  ///
  /// In en, this message translates to:
  /// **'One more will confirm whether this repeats.'**
  String get v1Copy0112;

  /// No description provided for @v1Copy0113.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs one more entry before it can compare clearly.'**
  String get v1Copy0113;

  /// No description provided for @v1Copy0114.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting a cautious possible pattern. '**
  String get v1Copy0114;

  /// No description provided for @v1Copy0115.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry to strengthen the evidence.'**
  String get v1Copy0115;

  /// No description provided for @v1Copy0116.
  ///
  /// In en, this message translates to:
  /// **'You added one piece today.'**
  String get v1Copy0116;

  /// No description provided for @v1Copy0117.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has one entry to compare later.'**
  String get v1Copy0117;

  /// No description provided for @v1Copy0118.
  ///
  /// In en, this message translates to:
  /// **'Record that entry only if it happens again.'**
  String get v1Copy0118;

  /// No description provided for @v1Copy0119.
  ///
  /// In en, this message translates to:
  /// **'I recorded one entry for my archive.'**
  String get v1Copy0119;

  /// No description provided for @v1Copy0120.
  ///
  /// In en, this message translates to:
  /// **'Share safely'**
  String get v1Copy0120;

  /// No description provided for @v1Copy0121.
  ///
  /// In en, this message translates to:
  /// **'Share Thoughtprint without exposing private entries.'**
  String get v1Copy0121;

  /// No description provided for @v1Copy0122.
  ///
  /// In en, this message translates to:
  /// **'My archive is starting to show what keeps coming back.'**
  String get v1Copy0122;

  /// No description provided for @v1Copy0123.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is helping me notice what repeats — with evidence, not guesses.'**
  String get v1Copy0123;

  /// No description provided for @v1Copy0124.
  ///
  /// In en, this message translates to:
  /// **'I recorded entries. My archive started showing the pattern.'**
  String get v1Copy0124;

  /// No description provided for @v1Copy0125.
  ///
  /// In en, this message translates to:
  /// **'No private entries shared.'**
  String get v1Copy0125;

  /// No description provided for @v1Copy0126.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint — your private evidence-based life archive.'**
  String get v1Copy0126;

  /// No description provided for @v1Copy0127.
  ///
  /// In en, this message translates to:
  /// **'Pattern your archive is watching'**
  String get v1Copy0127;

  /// No description provided for @v1Copy0128.
  ///
  /// In en, this message translates to:
  /// **'A second entry can show whether the same pattern returns.'**
  String get v1Copy0128;

  /// No description provided for @v1Copy0129.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry.'**
  String get v1Copy0129;

  /// No description provided for @v1Copy0130.
  ///
  /// In en, this message translates to:
  /// **'Your archive has one piece. Come back when this shows up again.'**
  String get v1Copy0130;

  /// No description provided for @v1Copy0131.
  ///
  /// In en, this message translates to:
  /// **'One more entry can make the pattern clearer.'**
  String get v1Copy0131;

  /// No description provided for @v1Copy0132.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has two entries to compare. '**
  String get v1Copy0132;

  /// No description provided for @v1Copy0133.
  ///
  /// In en, this message translates to:
  /// **'A third can help it form a cautious first possible pattern.'**
  String get v1Copy0133;

  /// No description provided for @v1Copy0134.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to see a possible pattern.'**
  String get v1Copy0134;

  /// No description provided for @v1Copy0135.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry to test whether the evidence holds.'**
  String get v1Copy0135;

  /// No description provided for @v1Copy0136.
  ///
  /// In en, this message translates to:
  /// **'Review what changed, then add another entry when it shows up again.'**
  String get v1Copy0136;

  /// No description provided for @v1Copy0137.
  ///
  /// In en, this message translates to:
  /// **'Your archive review is ready.'**
  String get v1Copy0137;

  /// No description provided for @v1Copy0138.
  ///
  /// In en, this message translates to:
  /// **'See what your recorded words are starting to show this week.'**
  String get v1Copy0138;

  /// No description provided for @v1Copy0139.
  ///
  /// In en, this message translates to:
  /// **'Your archive needs another recorded entry before it can compare.'**
  String get v1Copy0139;

  /// No description provided for @v1Copy0140.
  ///
  /// In en, this message translates to:
  /// **'Add the entry that makes this clearer.'**
  String get v1Copy0140;

  /// No description provided for @v1Copy0141.
  ///
  /// In en, this message translates to:
  /// **'Test this possible pattern with one more entry.'**
  String get v1Copy0141;

  /// No description provided for @v1Copy0142.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to see a possible pattern. '**
  String get v1Copy0142;

  /// No description provided for @v1Copy0143.
  ///
  /// In en, this message translates to:
  /// **'Another example can show whether the evidence holds.'**
  String get v1Copy0143;

  /// No description provided for @v1Copy0144.
  ///
  /// In en, this message translates to:
  /// **'Add the entry that would change the evidence.'**
  String get v1Copy0144;

  /// No description provided for @v1Copy0145.
  ///
  /// In en, this message translates to:
  /// **'Your archive noticed something. '**
  String get v1Copy0145;

  /// No description provided for @v1Copy0146.
  ///
  /// In en, this message translates to:
  /// **'Record the next entry when this shows up in a new context.'**
  String get v1Copy0146;

  /// No description provided for @v1Copy0147.
  ///
  /// In en, this message translates to:
  /// **'Help your archive review the week.'**
  String get v1Copy0147;

  /// No description provided for @v1Copy0148.
  ///
  /// In en, this message translates to:
  /// **'Record the next entry that confirms, weakens, or changes '**
  String get v1Copy0148;

  /// No description provided for @v1Copy0149.
  ///
  /// In en, this message translates to:
  /// **'this week\\u2019s strongest thread.'**
  String get v1Copy0149;

  /// No description provided for @v1Copy0150.
  ///
  /// In en, this message translates to:
  /// **'Add a entry that clarifies your correction.'**
  String get v1Copy0150;

  /// No description provided for @v1Copy0151.
  ///
  /// In en, this message translates to:
  /// **'You marked an archive insight as not quite right. '**
  String get v1Copy0151;

  /// No description provided for @v1Copy0152.
  ///
  /// In en, this message translates to:
  /// **'Record the next example that shows what Thoughtprint missed.'**
  String get v1Copy0152;

  /// No description provided for @v1Copy0153.
  ///
  /// In en, this message translates to:
  /// **'Help Thoughtprint retest this possible pattern.'**
  String get v1Copy0153;

  /// No description provided for @v1Copy0154.
  ///
  /// In en, this message translates to:
  /// **'Your note says this insight missed something. '**
  String get v1Copy0154;

  /// No description provided for @v1Copy0155.
  ///
  /// In en, this message translates to:
  /// **'Add the next entry that supports, weakens, or changes the evidence.'**
  String get v1Copy0155;

  /// No description provided for @v1Copy0156.
  ///
  /// In en, this message translates to:
  /// **'Help your review learn from your correction.'**
  String get v1Copy0156;

  /// No description provided for @v1Copy0157.
  ///
  /// In en, this message translates to:
  /// **'Record the next entry that shows whether your correction '**
  String get v1Copy0157;

  /// No description provided for @v1Copy0158.
  ///
  /// In en, this message translates to:
  /// **'holds across more than one example.'**
  String get v1Copy0158;

  /// No description provided for @v1Copy0159.
  ///
  /// In en, this message translates to:
  /// **'One more distinct recorded entry would help Thoughtprint compare this more '**
  String get v1Copy0159;

  /// No description provided for @v1Copy0160.
  ///
  /// In en, this message translates to:
  /// **'Partly fits'**
  String get v1Copy0160;

  /// No description provided for @v1Copy0161.
  ///
  /// In en, this message translates to:
  /// **'Why am I seeing this?'**
  String get v1Copy0161;

  /// No description provided for @v1Copy0162.
  ///
  /// In en, this message translates to:
  /// **'You can hide this if it does not feel useful.'**
  String get v1Copy0162;

  /// No description provided for @v1Copy0163.
  ///
  /// In en, this message translates to:
  /// **'Your archive is still testing this possible pattern.'**
  String get v1Copy0163;

  /// No description provided for @v1Copy0164.
  ///
  /// In en, this message translates to:
  /// **'This may not be quite right yet.'**
  String get v1Copy0164;

  /// No description provided for @v1Copy0165.
  ///
  /// In en, this message translates to:
  /// **'The evidence needs another entry before this is useful.'**
  String get v1Copy0165;

  /// No description provided for @v1Copy0166.
  ///
  /// In en, this message translates to:
  /// **'Recorded as useful feedback.'**
  String get v1Copy0166;

  /// No description provided for @v1Copy0167.
  ///
  /// In en, this message translates to:
  /// **'Tell Thoughtprint what it missed'**
  String get v1Copy0167;

  /// No description provided for @v1Copy0168.
  ///
  /// In en, this message translates to:
  /// **'Add a private note\\u2026'**
  String get v1Copy0168;

  /// No description provided for @v1Copy0169.
  ///
  /// In en, this message translates to:
  /// **'You marked this as not quite right.'**
  String get v1Copy0169;

  /// No description provided for @v1Copy0170.
  ///
  /// In en, this message translates to:
  /// **'Your note:'**
  String get v1Copy0170;

  /// No description provided for @v1Copy0171.
  ///
  /// In en, this message translates to:
  /// **'Insight quality'**
  String get v1Copy0171;

  /// No description provided for @v1Copy0172.
  ///
  /// In en, this message translates to:
  /// **'Control what Thoughtprint learns from your feedback. This stays on this device.'**
  String get v1Copy0172;

  /// No description provided for @v1Copy0173.
  ///
  /// In en, this message translates to:
  /// **'Manage feedback'**
  String get v1Copy0173;

  /// No description provided for @v1Copy0174.
  ///
  /// In en, this message translates to:
  /// **'Feedback summary'**
  String get v1Copy0174;

  /// No description provided for @v1Copy0175.
  ///
  /// In en, this message translates to:
  /// **'Hidden insights'**
  String get v1Copy0175;

  /// No description provided for @v1Copy0176.
  ///
  /// In en, this message translates to:
  /// **'Correction notes'**
  String get v1Copy0176;

  /// No description provided for @v1Copy0177.
  ///
  /// In en, this message translates to:
  /// **'Insights marked Partly fits'**
  String get v1Copy0177;

  /// No description provided for @v1Copy0178.
  ///
  /// In en, this message translates to:
  /// **'No local feedback yet'**
  String get v1Copy0178;

  /// No description provided for @v1Copy0179.
  ///
  /// In en, this message translates to:
  /// **'When you respond to archive insights, your feedback will appear here.'**
  String get v1Copy0179;

  /// No description provided for @v1Copy0180.
  ///
  /// In en, this message translates to:
  /// **'Your feedback stays on this device.'**
  String get v1Copy0180;

  /// No description provided for @v1Copy0181.
  ///
  /// In en, this message translates to:
  /// **'Correction notes are not shared.'**
  String get v1Copy0181;

  /// No description provided for @v1Copy0182.
  ///
  /// In en, this message translates to:
  /// **'Share safely never includes your private notes.'**
  String get v1Copy0182;

  /// No description provided for @v1Copy0183.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get v1Copy0183;

  /// No description provided for @v1Copy0184.
  ///
  /// In en, this message translates to:
  /// **'Clear feedback'**
  String get v1Copy0184;

  /// No description provided for @v1Copy0185.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get v1Copy0185;

  /// No description provided for @v1Copy0186.
  ///
  /// In en, this message translates to:
  /// **'More cautious copy is active.'**
  String get v1Copy0186;

  /// No description provided for @v1Copy0187.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is still testing this insight.'**
  String get v1Copy0187;

  /// No description provided for @v1Copy0188.
  ///
  /// In en, this message translates to:
  /// **'Archive Home'**
  String get v1Copy0188;

  /// No description provided for @v1Copy0189.
  ///
  /// In en, this message translates to:
  /// **'Archive Home (three entries)'**
  String get v1Copy0189;

  /// No description provided for @v1Copy0190.
  ///
  /// In en, this message translates to:
  /// **'Archive Home (four entries)'**
  String get v1Copy0190;

  /// No description provided for @v1Copy0191.
  ///
  /// In en, this message translates to:
  /// **'Archive Home (weekly review stage)'**
  String get v1Copy0191;

  /// No description provided for @v1Copy0192.
  ///
  /// In en, this message translates to:
  /// **'Weekly archive review'**
  String get v1Copy0192;

  /// No description provided for @v1Copy0193.
  ///
  /// In en, this message translates to:
  /// **'Evidence trail'**
  String get v1Copy0193;

  /// No description provided for @v1Copy0194.
  ///
  /// In en, this message translates to:
  /// **'Pattern update'**
  String get v1Copy0194;

  /// No description provided for @v1Copy0195.
  ///
  /// In en, this message translates to:
  /// **'Archive health'**
  String get v1Copy0195;

  /// No description provided for @v1Copy0196.
  ///
  /// In en, this message translates to:
  /// **'Based on usable recorded entries on this device.'**
  String get v1Copy0196;

  /// No description provided for @v1Copy0197.
  ///
  /// In en, this message translates to:
  /// **'Usable entries'**
  String get v1Copy0197;

  /// No description provided for @v1Copy0198.
  ///
  /// In en, this message translates to:
  /// **'Evidence quality'**
  String get v1Copy0198;

  /// No description provided for @v1Copy0199.
  ///
  /// In en, this message translates to:
  /// **'What needs more evidence'**
  String get v1Copy0199;

  /// No description provided for @v1Copy0200.
  ///
  /// In en, this message translates to:
  /// **'Evidence is still thin.'**
  String get v1Copy0200;

  /// No description provided for @v1Copy0201.
  ///
  /// In en, this message translates to:
  /// **'Your archive is starting to compare.'**
  String get v1Copy0201;

  /// No description provided for @v1Copy0202.
  ///
  /// In en, this message translates to:
  /// **'Your archive has enough to form a cautious first possible pattern.'**
  String get v1Copy0202;

  /// No description provided for @v1Copy0203.
  ///
  /// In en, this message translates to:
  /// **'Possible patterns are not conclusions.'**
  String get v1Copy0203;

  /// No description provided for @v1Copy0204.
  ///
  /// In en, this message translates to:
  /// **'Your archive has enough evidence to update a possible pattern.'**
  String get v1Copy0204;

  /// No description provided for @v1Copy0205.
  ///
  /// In en, this message translates to:
  /// **'Your archive is getting clearer.'**
  String get v1Copy0205;

  /// No description provided for @v1Copy0206.
  ///
  /// In en, this message translates to:
  /// **'Your archive has enough to create a review.'**
  String get v1Copy0206;

  /// No description provided for @v1Copy0207.
  ///
  /// In en, this message translates to:
  /// **'Evidence is stronger when entries appear across more than one context.'**
  String get v1Copy0207;

  /// No description provided for @v1Copy0208.
  ///
  /// In en, this message translates to:
  /// **'Your archive has enough to review.'**
  String get v1Copy0208;

  /// No description provided for @v1Copy0209.
  ///
  /// In en, this message translates to:
  /// **'recorded entries were too short or unclear to count'**
  String get v1Copy0209;

  /// No description provided for @v1Copy0210.
  ///
  /// In en, this message translates to:
  /// **'Some recorded entries look very similar.'**
  String get v1Copy0210;

  /// No description provided for @v1Copy0211.
  ///
  /// In en, this message translates to:
  /// **'Some recorded entries look nearly the same.'**
  String get v1Copy0211;

  /// No description provided for @v1Copy0212.
  ///
  /// In en, this message translates to:
  /// **'Some insights were marked not quite right.'**
  String get v1Copy0212;

  /// No description provided for @v1Copy0213.
  ///
  /// In en, this message translates to:
  /// **'Correction notes are active on this device.'**
  String get v1Copy0213;

  /// No description provided for @v1Copy0214.
  ///
  /// In en, this message translates to:
  /// **'Local feedback suggests staying cautious.'**
  String get v1Copy0214;

  /// No description provided for @v1Copy0215.
  ///
  /// In en, this message translates to:
  /// **'Record one more ordinary entry.'**
  String get v1Copy0215;

  /// No description provided for @v1Copy0216.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry from a different part of your day.'**
  String get v1Copy0216;

  /// No description provided for @v1Copy0217.
  ///
  /// In en, this message translates to:
  /// **'Add a entry that tests the first cautious possible pattern.'**
  String get v1Copy0217;

  /// No description provided for @v1Copy0218.
  ///
  /// In en, this message translates to:
  /// **'Add a entry that might change what the archive notices.'**
  String get v1Copy0218;

  /// No description provided for @v1Copy0219.
  ///
  /// In en, this message translates to:
  /// **'Add a entry from a different context to strengthen the review.'**
  String get v1Copy0219;

  /// No description provided for @v1Copy0220.
  ///
  /// In en, this message translates to:
  /// **'Add a entry with different words or context.'**
  String get v1Copy0220;

  /// No description provided for @v1Copy0221.
  ///
  /// In en, this message translates to:
  /// **'Add one more distinct recorded entry.'**
  String get v1Copy0221;

  /// No description provided for @v1Copy0222.
  ///
  /// In en, this message translates to:
  /// **'Improve your archive'**
  String get v1Copy0222;

  /// No description provided for @v1Copy0223.
  ///
  /// In en, this message translates to:
  /// **'Small steps that make your archive more useful.'**
  String get v1Copy0223;

  /// No description provided for @v1Copy0224.
  ///
  /// In en, this message translates to:
  /// **'What would help next'**
  String get v1Copy0224;

  /// No description provided for @v1Copy0225.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry before Thoughtprint compares anything.'**
  String get v1Copy0225;

  /// No description provided for @v1Copy0226.
  ///
  /// In en, this message translates to:
  /// **'Add a third entry to help form a cautious first possible pattern.'**
  String get v1Copy0226;

  /// No description provided for @v1Copy0227.
  ///
  /// In en, this message translates to:
  /// **'Add a entry from a different context.'**
  String get v1Copy0227;

  /// No description provided for @v1Copy0228.
  ///
  /// In en, this message translates to:
  /// **'Add text to recorded entries that were too unclear.'**
  String get v1Copy0228;

  /// No description provided for @v1Copy0229.
  ///
  /// In en, this message translates to:
  /// **'Where did this show up?'**
  String get v1Copy0229;

  /// No description provided for @v1Copy0230.
  ///
  /// In en, this message translates to:
  /// **'Tags stay on this device and help your archive compare entries.'**
  String get v1Copy0230;

  /// No description provided for @v1Copy0231.
  ///
  /// In en, this message translates to:
  /// **'No context tag'**
  String get v1Copy0231;

  /// No description provided for @v1Copy0233.
  ///
  /// In en, this message translates to:
  /// **'Edit context'**
  String get v1Copy0233;

  /// No description provided for @v1Copy0234.
  ///
  /// In en, this message translates to:
  /// **'Edit context tag'**
  String get v1Copy0234;

  /// No description provided for @v1Copy0235.
  ///
  /// In en, this message translates to:
  /// **'Clear tag'**
  String get v1Copy0235;

  /// No description provided for @v1Copy0236.
  ///
  /// In en, this message translates to:
  /// **'Tagged entries so far share one context.'**
  String get v1Copy0236;

  /// No description provided for @v1Copy0237.
  ///
  /// In en, this message translates to:
  /// **'Tagged entries may span more than one context.'**
  String get v1Copy0237;

  /// No description provided for @v1Copy0238.
  ///
  /// In en, this message translates to:
  /// **'Where this shows up'**
  String get v1Copy0238;

  /// No description provided for @v1Copy0239.
  ///
  /// In en, this message translates to:
  /// **'Based on optional tags recorded on this device.'**
  String get v1Copy0239;

  /// No description provided for @v1Copy0240.
  ///
  /// In en, this message translates to:
  /// **'Your archive has one tagged entry.'**
  String get v1Copy0240;

  /// No description provided for @v1Copy0241.
  ///
  /// In en, this message translates to:
  /// **'Add another tagged entry to compare contexts.'**
  String get v1Copy0241;

  /// No description provided for @v1Copy0243.
  ///
  /// In en, this message translates to:
  /// **'Add a entry from a different context to see whether it travels.'**
  String get v1Copy0243;

  /// No description provided for @v1Copy0244.
  ///
  /// In en, this message translates to:
  /// **'This is showing up across more than one context.'**
  String get v1Copy0244;

  /// No description provided for @v1Copy0245.
  ///
  /// In en, this message translates to:
  /// **'The context evidence is still thin.'**
  String get v1Copy0245;

  /// No description provided for @v1Copy0246.
  ///
  /// In en, this message translates to:
  /// **'Tagged entries by context'**
  String get v1Copy0246;

  /// No description provided for @v1Copy0247.
  ///
  /// In en, this message translates to:
  /// **'This is mostly showing up at work.'**
  String get v1Copy0247;

  /// No description provided for @v1Copy0248.
  ///
  /// In en, this message translates to:
  /// **'This is mostly showing up at home.'**
  String get v1Copy0248;

  /// No description provided for @v1Copy0250.
  ///
  /// In en, this message translates to:
  /// **'This has shown up in more than one context.'**
  String get v1Copy0250;

  /// No description provided for @v1Copy0252.
  ///
  /// In en, this message translates to:
  /// **'Evidence map'**
  String get v1Copy0252;

  /// No description provided for @v1Copy0253.
  ///
  /// In en, this message translates to:
  /// **'Where your recorded entries are showing up on this device.'**
  String get v1Copy0253;

  /// No description provided for @v1Copy0254.
  ///
  /// In en, this message translates to:
  /// **'Your archive needs a recorded entry before it can map evidence.'**
  String get v1Copy0254;

  /// No description provided for @v1Copy0255.
  ///
  /// In en, this message translates to:
  /// **'Your evidence map has one tagged entry.'**
  String get v1Copy0255;

  /// No description provided for @v1Copy0256.
  ///
  /// In en, this message translates to:
  /// **'Add another entry to compare contexts.'**
  String get v1Copy0256;

  /// No description provided for @v1Copy0258.
  ///
  /// In en, this message translates to:
  /// **'Your evidence spans more than one context.'**
  String get v1Copy0258;

  /// No description provided for @v1Copy0259.
  ///
  /// In en, this message translates to:
  /// **'Add context tags to make your evidence map clearer.'**
  String get v1Copy0259;

  /// No description provided for @v1Copy0260.
  ///
  /// In en, this message translates to:
  /// **'Unclear recordings are excluded from evidence quality.'**
  String get v1Copy0260;

  /// No description provided for @v1Copy0261.
  ///
  /// In en, this message translates to:
  /// **'Strongest context'**
  String get v1Copy0261;

  /// No description provided for @v1Copy0262.
  ///
  /// In en, this message translates to:
  /// **'Thin contexts'**
  String get v1Copy0262;

  /// No description provided for @v1Copy0263.
  ///
  /// In en, this message translates to:
  /// **'Untagged entries'**
  String get v1Copy0263;

  /// No description provided for @v1Copy0264.
  ///
  /// In en, this message translates to:
  /// **'1 entry does not have a context tag yet.'**
  String get v1Copy0264;

  /// No description provided for @v1Copy0270.
  ///
  /// In en, this message translates to:
  /// **'Untagged evidence'**
  String get v1Copy0270;

  /// No description provided for @v1Copy0271.
  ///
  /// In en, this message translates to:
  /// **'Recorded entries counted in your evidence map.'**
  String get v1Copy0271;

  /// No description provided for @v1Copy0272.
  ///
  /// In en, this message translates to:
  /// **'No recorded entries are counted in this context right now.'**
  String get v1Copy0272;

  /// No description provided for @v1Copy0273.
  ///
  /// In en, this message translates to:
  /// **'Open entry'**
  String get v1Copy0273;

  /// No description provided for @v1Copy0274.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get v1Copy0274;

  /// No description provided for @v1Copy0275.
  ///
  /// In en, this message translates to:
  /// **'Same context'**
  String get v1Copy0275;

  /// No description provided for @v1Copy0276.
  ///
  /// In en, this message translates to:
  /// **'Review and history'**
  String get v1Copy0276;

  /// No description provided for @v1Copy0277.
  ///
  /// In en, this message translates to:
  /// **'Next best actions'**
  String get v1Copy0277;

  /// No description provided for @v1Copy0278.
  ///
  /// In en, this message translates to:
  /// **'Tag untagged entries'**
  String get v1Copy0278;

  /// No description provided for @v1Copy0279.
  ///
  /// In en, this message translates to:
  /// **'Review corrections'**
  String get v1Copy0279;

  /// No description provided for @v1Copy0280.
  ///
  /// In en, this message translates to:
  /// **'View evidence map'**
  String get v1Copy0280;

  /// No description provided for @v1Copy0281.
  ///
  /// In en, this message translates to:
  /// **'View weekly review'**
  String get v1Copy0281;

  /// No description provided for @v1Copy0282.
  ///
  /// In en, this message translates to:
  /// **'This is your private archive workspace.'**
  String get v1Copy0282;

  /// No description provided for @v1Copy0283.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint uses your recorded entries to show evidence, patterns, and what to add next.'**
  String get v1Copy0283;

  /// No description provided for @v1Copy0284.
  ///
  /// In en, this message translates to:
  /// **'These shortcuts point to evidence that may need a tag, correction, or another entry.'**
  String get v1Copy0284;

  /// No description provided for @v1Copy0285.
  ///
  /// In en, this message translates to:
  /// **'This section shows where your archive has enough evidence, and where it is still thin.'**
  String get v1Copy0285;

  /// No description provided for @v1Copy0286.
  ///
  /// In en, this message translates to:
  /// **'When you have enough recorded entries, Thoughtprint can show how a possible pattern may have changed.'**
  String get v1Copy0286;

  /// No description provided for @v1Copy0287.
  ///
  /// In en, this message translates to:
  /// **'Why this section?'**
  String get v1Copy0287;

  /// No description provided for @v1Copy0288.
  ///
  /// In en, this message translates to:
  /// **'These entries may be related'**
  String get v1Copy0288;

  /// No description provided for @v1Copy0289.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint noticed similar wording across two recorded entries. '**
  String get v1Copy0289;

  /// No description provided for @v1Copy0290.
  ///
  /// In en, this message translates to:
  /// **'This is not an established pattern yet.'**
  String get v1Copy0290;

  /// No description provided for @v1Copy0291.
  ///
  /// In en, this message translates to:
  /// **'Possible pattern'**
  String get v1Copy0291;

  /// No description provided for @v1Copy0292.
  ///
  /// In en, this message translates to:
  /// **'These entries may repeat a similar theme. Review the evidence '**
  String get v1Copy0292;

  /// No description provided for @v1Copy0293.
  ///
  /// In en, this message translates to:
  /// **'before treating it as settled.'**
  String get v1Copy0293;

  /// No description provided for @v1Copy0294.
  ///
  /// In en, this message translates to:
  /// **'What may have changed'**
  String get v1Copy0294;

  /// No description provided for @v1Copy0295.
  ///
  /// In en, this message translates to:
  /// **'Your earlier and recent entries describe this differently. '**
  String get v1Copy0295;

  /// No description provided for @v1Copy0296.
  ///
  /// In en, this message translates to:
  /// **'This does not prove improvement or causation.'**
  String get v1Copy0296;

  /// No description provided for @v1Copy0297.
  ///
  /// In en, this message translates to:
  /// **'Not for me'**
  String get v1Copy0297;

  /// No description provided for @v1Copy0298.
  ///
  /// In en, this message translates to:
  /// **'Your words'**
  String get v1Copy0298;

  /// No description provided for @v1Copy0299.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint suggestion'**
  String get v1Copy0299;

  /// No description provided for @v1Copy0300.
  ///
  /// In en, this message translates to:
  /// **'Review status'**
  String get v1Copy0300;

  /// No description provided for @v1Copy0301.
  ///
  /// In en, this message translates to:
  /// **'Possible patterns Thoughtprint is watching'**
  String get v1Copy0301;

  /// No description provided for @v1Copy0302.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint does not have enough evidence yet.'**
  String get v1Copy0302;

  /// No description provided for @v1Copy0303.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint may need more entries before this feels settled.'**
  String get v1Copy0303;

  /// No description provided for @v1Copy0304.
  ///
  /// In en, this message translates to:
  /// **'How often it shows up'**
  String get v1Copy0304;

  /// No description provided for @v1Copy0305.
  ///
  /// In en, this message translates to:
  /// **'Entries that may not fit'**
  String get v1Copy0305;

  /// No description provided for @v1Copy0306.
  ///
  /// In en, this message translates to:
  /// **'Missing evidence'**
  String get v1Copy0306;

  /// No description provided for @v1Copy0307.
  ///
  /// In en, this message translates to:
  /// **'What would strengthen this possible pattern'**
  String get v1Copy0307;

  /// No description provided for @v1Copy0308.
  ///
  /// In en, this message translates to:
  /// **'Show me why'**
  String get v1Copy0308;

  /// No description provided for @v1Copy0309.
  ///
  /// In en, this message translates to:
  /// **'What may be missing'**
  String get v1Copy0309;

  /// No description provided for @v1Copy0310.
  ///
  /// In en, this message translates to:
  /// **'Why does Thoughtprint suggest this?'**
  String get v1Copy0310;

  /// No description provided for @v1Copy0311.
  ///
  /// In en, this message translates to:
  /// **'Why the archive moved'**
  String get v1Copy0311;

  /// No description provided for @v1Copy0312.
  ///
  /// In en, this message translates to:
  /// **'Your archive updated its view of a possible pattern.'**
  String get v1Copy0312;

  /// No description provided for @v1Copy0313.
  ///
  /// In en, this message translates to:
  /// **'Evidence shifted'**
  String get v1Copy0313;

  /// No description provided for @v1Copy0314.
  ///
  /// In en, this message translates to:
  /// **'Your archive added new evidence to an existing possible pattern.'**
  String get v1Copy0314;

  /// No description provided for @v1Copy0315.
  ///
  /// In en, this message translates to:
  /// **'A entry may not fit the earlier read.'**
  String get v1Copy0315;

  /// No description provided for @v1Copy0316.
  ///
  /// In en, this message translates to:
  /// **'A possible pattern may have weakened as new evidence arrived.'**
  String get v1Copy0316;

  /// No description provided for @v1Copy0317.
  ///
  /// In en, this message translates to:
  /// **'A possible pattern may have strengthened as new evidence arrived.'**
  String get v1Copy0317;

  /// No description provided for @v1Copy0318.
  ///
  /// In en, this message translates to:
  /// **'No major change yet. This reflection still gives the archive another comparison point.'**
  String get v1Copy0318;

  /// No description provided for @v1Copy0319.
  ///
  /// In en, this message translates to:
  /// **'Evidence ledger'**
  String get v1Copy0319;

  /// No description provided for @v1Copy0320.
  ///
  /// In en, this message translates to:
  /// **'Possible patterns, changes, and evidence from your archive.'**
  String get v1Copy0320;

  /// No description provided for @v1Copy0321.
  ///
  /// In en, this message translates to:
  /// **'Search entries, patterns, and evidence…'**
  String get v1Copy0321;

  /// No description provided for @v1Copy0322.
  ///
  /// In en, this message translates to:
  /// **'No indexed evidence yet'**
  String get v1Copy0322;

  /// No description provided for @v1Copy0323.
  ///
  /// In en, this message translates to:
  /// **'Record a entry and let Thoughtprint index citable facts — they will appear here.'**
  String get v1Copy0323;

  /// No description provided for @v1Copy0324.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get v1Copy0324;

  /// No description provided for @v1Copy0325.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get v1Copy0325;

  /// No description provided for @v1Copy0326.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get v1Copy0326;

  /// No description provided for @v1Copy0327.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get v1Copy0327;

  /// No description provided for @v1Copy0328.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search or date filter.'**
  String get v1Copy0328;

  /// No description provided for @v1Copy0329.
  ///
  /// In en, this message translates to:
  /// **'1 Citable Fact'**
  String get v1Copy0329;

  /// No description provided for @v1Copy0331.
  ///
  /// In en, this message translates to:
  /// **'1 Entry'**
  String get v1Copy0331;

  /// No description provided for @v1Copy0336.
  ///
  /// In en, this message translates to:
  /// **'No cited ledger entries yet · Tap to inspect'**
  String get v1Copy0336;

  /// No description provided for @v1Copy0337.
  ///
  /// In en, this message translates to:
  /// **'Not enough linked recordings yet. Record another entry with a little more detail.'**
  String get v1Copy0337;

  /// No description provided for @v1Copy0338.
  ///
  /// In en, this message translates to:
  /// **'How close does this feel to your entries?'**
  String get v1Copy0338;

  /// No description provided for @v1Copy0339.
  ///
  /// In en, this message translates to:
  /// **'Support & feedback'**
  String get v1Copy0339;

  /// No description provided for @v1Copy0340.
  ///
  /// In en, this message translates to:
  /// **'Get help or share what is not working.'**
  String get v1Copy0340;

  /// No description provided for @v1Copy0341.
  ///
  /// In en, this message translates to:
  /// **'Need help?'**
  String get v1Copy0341;

  /// No description provided for @v1Copy0342.
  ///
  /// In en, this message translates to:
  /// **'For support, use the Thoughtprint support page.'**
  String get v1Copy0342;

  /// No description provided for @v1Copy0343.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get v1Copy0343;

  /// No description provided for @v1Copy0344.
  ///
  /// In en, this message translates to:
  /// **'Tell us what happened, what you expected, and whether it involved '**
  String get v1Copy0344;

  /// No description provided for @v1Copy0345.
  ///
  /// In en, this message translates to:
  /// **'Record, Archive, Sample Archive, Export, or Settings.'**
  String get v1Copy0345;

  /// No description provided for @v1Copy0346.
  ///
  /// In en, this message translates to:
  /// **'Privacy reminder'**
  String get v1Copy0346;

  /// No description provided for @v1Copy0347.
  ///
  /// In en, this message translates to:
  /// **'Do not send private entries unless you choose to include them.'**
  String get v1Copy0347;

  /// No description provided for @v1Copy0348.
  ///
  /// In en, this message translates to:
  /// **'Share-safe summary does not include raw private entries.'**
  String get v1Copy0348;

  /// No description provided for @v1Copy0349.
  ///
  /// In en, this message translates to:
  /// **'Useful testing paths'**
  String get v1Copy0349;

  /// No description provided for @v1Copy0351.
  ///
  /// In en, this message translates to:
  /// **'Use Sample Archive to explore the product without adding private entries.'**
  String get v1Copy0351;

  /// No description provided for @v1Copy0352.
  ///
  /// In en, this message translates to:
  /// **'Open support page'**
  String get v1Copy0352;

  /// No description provided for @v1Copy0353.
  ///
  /// In en, this message translates to:
  /// **'Copy support checklist'**
  String get v1Copy0353;

  /// No description provided for @v1Copy0354.
  ///
  /// In en, this message translates to:
  /// **'Open Help & reviewer guide'**
  String get v1Copy0354;

  /// No description provided for @v1Copy0355.
  ///
  /// In en, this message translates to:
  /// **'Open Sample Archive'**
  String get v1Copy0355;

  /// No description provided for @v1Copy0356.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint support checklist'**
  String get v1Copy0356;

  /// No description provided for @v1Copy0357.
  ///
  /// In en, this message translates to:
  /// **'Support checklist copied'**
  String get v1Copy0357;

  /// No description provided for @v1Copy0358.
  ///
  /// In en, this message translates to:
  /// **'Record a private entry'**
  String get v1Copy0358;

  /// No description provided for @v1Copy0359.
  ///
  /// In en, this message translates to:
  /// **'See what repeats over time'**
  String get v1Copy0359;

  /// No description provided for @v1Copy0360.
  ///
  /// In en, this message translates to:
  /// **'Review evidence, not guesses'**
  String get v1Copy0360;

  /// No description provided for @v1Copy0361.
  ///
  /// In en, this message translates to:
  /// **'Explore your private archive'**
  String get v1Copy0361;

  /// No description provided for @v1Copy0362.
  ///
  /// In en, this message translates to:
  /// **'Export only when you choose'**
  String get v1Copy0362;

  /// No description provided for @v1Copy0363.
  ///
  /// In en, this message translates to:
  /// **'Try Sample Archive with example data'**
  String get v1Copy0363;

  /// No description provided for @v1Copy0364.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can be tested without microphone access by using Type instead.'**
  String get v1Copy0364;

  /// No description provided for @v1Copy0365.
  ///
  /// In en, this message translates to:
  /// **'Sample Archive uses example data only and does not write to the real journal.'**
  String get v1Copy0365;

  /// No description provided for @v1Copy0366.
  ///
  /// In en, this message translates to:
  /// **'RevenueCat purchases are unavailable until banking setup is complete; the free archive flow remains usable.'**
  String get v1Copy0366;

  /// No description provided for @v1Copy0367.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data controls are available in Settings.'**
  String get v1Copy0367;

  /// No description provided for @v1Copy0368.
  ///
  /// In en, this message translates to:
  /// **'Suggested review path'**
  String get v1Copy0368;

  /// No description provided for @v1Copy0369.
  ///
  /// In en, this message translates to:
  /// **'Open Sample Archive for example data that never writes to your journal.'**
  String get v1Copy0369;

  /// No description provided for @v1Copy0370.
  ///
  /// In en, this message translates to:
  /// **'Follow Good demo paths inside Sample Archive for screenshots or demos.'**
  String get v1Copy0370;

  /// No description provided for @v1Copy0371.
  ///
  /// In en, this message translates to:
  /// **'Support and feedback are available from Settings.'**
  String get v1Copy0371;

  /// No description provided for @v1Copy0372.
  ///
  /// In en, this message translates to:
  /// **'Privacy for reviewers'**
  String get v1Copy0372;

  /// No description provided for @v1Copy0373.
  ///
  /// In en, this message translates to:
  /// **'Your archive stays on this device. Share-safe summary and export paths never include raw private entries unless you explicitly choose to share them.'**
  String get v1Copy0373;

  /// No description provided for @v1Copy0374.
  ///
  /// In en, this message translates to:
  /// **'Demo path checklist'**
  String get v1Copy0374;

  /// No description provided for @v1Copy0375.
  ///
  /// In en, this message translates to:
  /// **'Follow Good demo paths inside Sample Archive'**
  String get v1Copy0375;

  /// No description provided for @v1Copy0376.
  ///
  /// In en, this message translates to:
  /// **'Open Evidence Map'**
  String get v1Copy0376;

  /// No description provided for @v1Copy0377.
  ///
  /// In en, this message translates to:
  /// **'Open Work context'**
  String get v1Copy0377;

  /// No description provided for @v1Copy0378.
  ///
  /// In en, this message translates to:
  /// **'Copy demo summary'**
  String get v1Copy0378;

  /// No description provided for @v1Copy0379.
  ///
  /// In en, this message translates to:
  /// **'Open Support & feedback for help or issues'**
  String get v1Copy0379;

  /// No description provided for @v1Copy0380.
  ///
  /// In en, this message translates to:
  /// **'Support URL'**
  String get v1Copy0380;

  /// No description provided for @v1Copy0385.
  ///
  /// In en, this message translates to:
  /// **'Your recordings and reflections are personal. Thoughtprint is private by '**
  String get v1Copy0385;

  /// No description provided for @v1Copy0386.
  ///
  /// In en, this message translates to:
  /// **'default. Audio and transcript text are sent only when you turn on '**
  String get v1Copy0386;

  /// No description provided for @v1Copy0387.
  ///
  /// In en, this message translates to:
  /// **'remote processing for a new entry.'**
  String get v1Copy0387;

  /// No description provided for @v1Copy0388.
  ///
  /// In en, this message translates to:
  /// **'What can leave this phone'**
  String get v1Copy0388;

  /// No description provided for @v1Copy0389.
  ///
  /// In en, this message translates to:
  /// **'Writing out a recording, or reading it against what you said before, '**
  String get v1Copy0389;

  /// No description provided for @v1Copy0390.
  ///
  /// In en, this message translates to:
  /// **'only happens off this phone if you turn on remote processing. Sync is '**
  String get v1Copy0390;

  /// No description provided for @v1Copy0391.
  ///
  /// In en, this message translates to:
  /// **'a different choice: if you sign in and back up, an encrypted copy can '**
  String get v1Copy0391;

  /// No description provided for @v1Copy0392.
  ///
  /// In en, this message translates to:
  /// **'leave this phone, and the server cannot read it. While remote '**
  String get v1Copy0392;

  /// No description provided for @v1Copy0393.
  ///
  /// In en, this message translates to:
  /// **'processing is off, those new words are not sent for a transcript or a '**
  String get v1Copy0393;

  /// No description provided for @v1Copy0397.
  ///
  /// In en, this message translates to:
  /// **'What stays on your device'**
  String get v1Copy0397;

  /// No description provided for @v1Copy0398.
  ///
  /// In en, this message translates to:
  /// **'Your archive entries, recorded details, action items, surfacing choices, '**
  String get v1Copy0398;

  /// No description provided for @v1Copy0399.
  ///
  /// In en, this message translates to:
  /// **'memory controls, packs, pins, and collections are stored locally by default. '**
  String get v1Copy0399;

  /// No description provided for @v1Copy0400.
  ///
  /// In en, this message translates to:
  /// **'Archive metadata and prefs stay on this device as well.'**
  String get v1Copy0400;

  /// No description provided for @v1Copy0401.
  ///
  /// In en, this message translates to:
  /// **'Cloud transcription and analysis'**
  String get v1Copy0401;

  /// No description provided for @v1Copy0402.
  ///
  /// In en, this message translates to:
  /// **'When remote processing is on, Thoughtprint sends recorded audio for '**
  String get v1Copy0402;

  /// No description provided for @v1Copy0403.
  ///
  /// In en, this message translates to:
  /// **'transcription and transcript text for reflection. When it is off, '**
  String get v1Copy0403;

  /// No description provided for @v1Copy0404.
  ///
  /// In en, this message translates to:
  /// **'new entries are recorded on this device only. Anything already recorded '**
  String get v1Copy0404;

  /// No description provided for @v1Copy0405.
  ///
  /// In en, this message translates to:
  /// **'stays exactly as it is.'**
  String get v1Copy0405;

  /// No description provided for @v1Copy0406.
  ///
  /// In en, this message translates to:
  /// **'Optional encrypted backup'**
  String get v1Copy0406;

  /// No description provided for @v1Copy0407.
  ///
  /// In en, this message translates to:
  /// **'If you sign in and enable sync, backup data is encrypted before it is '**
  String get v1Copy0407;

  /// No description provided for @v1Copy0408.
  ///
  /// In en, this message translates to:
  /// **'uploaded, using a key held on this device. The server stores that '**
  String get v1Copy0408;

  /// No description provided for @v1Copy0409.
  ///
  /// In en, this message translates to:
  /// **'backup as ciphertext. Sync is optional.'**
  String get v1Copy0409;

  /// No description provided for @v1Copy0410.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint does not do'**
  String get v1Copy0410;

  /// No description provided for @v1Copy0411.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint does not sell your reflections. Thoughtprint does not include '**
  String get v1Copy0411;

  /// No description provided for @v1Copy0412.
  ///
  /// In en, this message translates to:
  /// **'recording text in analytics. Thoughtprint does not turn every entry into '**
  String get v1Copy0412;

  /// No description provided for @v1Copy0413.
  ///
  /// In en, this message translates to:
  /// **'personal memory by default. Thoughtprint is not therapy, medical advice, '**
  String get v1Copy0413;

  /// No description provided for @v1Copy0414.
  ///
  /// In en, this message translates to:
  /// **'or emergency support.'**
  String get v1Copy0414;

  /// No description provided for @v1Copy0415.
  ///
  /// In en, this message translates to:
  /// **'Ways to mark an entry'**
  String get v1Copy0415;

  /// No description provided for @v1Copy0416.
  ///
  /// In en, this message translates to:
  /// **'You can mark entries as Hypothetical, Not about me, Sensitive, '**
  String get v1Copy0416;

  /// No description provided for @v1Copy0417.
  ///
  /// In en, this message translates to:
  /// **'Do not surface, Preserve original, Keep separate, or Treat as new.'**
  String get v1Copy0417;

  /// No description provided for @v1Copy0418.
  ///
  /// In en, this message translates to:
  /// **'Processing providers'**
  String get v1Copy0418;

  /// No description provided for @v1Copy0419.
  ///
  /// In en, this message translates to:
  /// **'Remote processing is off until you turn it on, and these companies '**
  String get v1Copy0419;

  /// No description provided for @v1Copy0420.
  ///
  /// In en, this message translates to:
  /// **'receive nothing before then. If you turn it on: OpenAI receives a '**
  String get v1Copy0420;

  /// No description provided for @v1Copy0421.
  ///
  /// In en, this message translates to:
  /// **'along with structured details of the earlier entries it is compared '**
  String get v1Copy0421;

  /// No description provided for @v1Copy0422.
  ///
  /// In en, this message translates to:
  /// **'against — to draft a reflection. Google receives streamed audio during '**
  String get v1Copy0422;

  /// No description provided for @v1Copy0423.
  ///
  /// In en, this message translates to:
  /// **'a live conversation, where that feature is available. Encrypted backup '**
  String get v1Copy0423;

  /// No description provided for @v1Copy0424.
  ///
  /// In en, this message translates to:
  /// **'is separate: sync uploads ciphertext, so the server holds backup data '**
  String get v1Copy0424;

  /// No description provided for @v1Copy0425.
  ///
  /// In en, this message translates to:
  /// **'it cannot read.'**
  String get v1Copy0425;

  /// No description provided for @v1Copy0426.
  ///
  /// In en, this message translates to:
  /// **'Full privacy policy online'**
  String get v1Copy0426;

  /// No description provided for @v1Copy0427.
  ///
  /// In en, this message translates to:
  /// **'Remote processing'**
  String get v1Copy0427;

  /// No description provided for @v1Copy0428.
  ///
  /// In en, this message translates to:
  /// **'Send new entries for transcription and reflection'**
  String get v1Copy0428;

  /// No description provided for @v1Copy0429.
  ///
  /// In en, this message translates to:
  /// **'On — a new moment\'s audio and transcript may be sent to transcribe '**
  String get v1Copy0429;

  /// No description provided for @v1Copy0430.
  ///
  /// In en, this message translates to:
  /// **'and compare it against what you\'ve said before. Turn this off any '**
  String get v1Copy0430;

  /// No description provided for @v1Copy0431.
  ///
  /// In en, this message translates to:
  /// **'time; anything already recorded stays exactly as it is.'**
  String get v1Copy0431;

  /// No description provided for @v1Copy0432.
  ///
  /// In en, this message translates to:
  /// **'Off — new entries are recorded on this device only. Nothing is sent '**
  String get v1Copy0432;

  /// No description provided for @v1Copy0433.
  ///
  /// In en, this message translates to:
  /// **'for transcription or reflection until you turn this on.'**
  String get v1Copy0433;

  /// No description provided for @v1Copy0434.
  ///
  /// In en, this message translates to:
  /// **'Last turned on '**
  String get v1Copy0434;

  /// No description provided for @v1Copy0435.
  ///
  /// In en, this message translates to:
  /// **'Withdrawing here only changes what happens next — entries already '**
  String get v1Copy0435;

  /// No description provided for @v1Copy0436.
  ///
  /// In en, this message translates to:
  /// **'analyzed keep their existing reflection.'**
  String get v1Copy0436;

  /// No description provided for @v1Copy0437.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get v1Copy0437;

  /// No description provided for @v1Copy0438.
  ///
  /// In en, this message translates to:
  /// **'Last updated: June 2026'**
  String get v1Copy0438;

  /// No description provided for @v1Copy0439.
  ///
  /// In en, this message translates to:
  /// **'By using Thoughtprint you agree to these terms. '**
  String get v1Copy0439;

  /// No description provided for @v1Copy0440.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint helps you notice what keeps repeating in your own words.'**
  String get v1Copy0440;

  /// No description provided for @v1Copy0441.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint is'**
  String get v1Copy0441;

  /// No description provided for @v1Copy0442.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is a private archive for your own voice reflections. '**
  String get v1Copy0442;

  /// No description provided for @v1Copy0443.
  ///
  /// In en, this message translates to:
  /// **'It is not therapy, medical advice, coaching, or emergency support.'**
  String get v1Copy0443;

  /// No description provided for @v1Copy0444.
  ///
  /// In en, this message translates to:
  /// **'Your content'**
  String get v1Copy0444;

  /// No description provided for @v1Copy0445.
  ///
  /// In en, this message translates to:
  /// **'You keep ownership of what you record. You are responsible for what '**
  String get v1Copy0445;

  /// No description provided for @v1Copy0446.
  ///
  /// In en, this message translates to:
  /// **'you choose to speak, export, or share outside the app.'**
  String get v1Copy0446;

  /// No description provided for @v1Copy0447.
  ///
  /// In en, this message translates to:
  /// **'Acceptable use'**
  String get v1Copy0447;

  /// No description provided for @v1Copy0448.
  ///
  /// In en, this message translates to:
  /// **'Do not use Thoughtprint to store illegal content or to harass others. '**
  String get v1Copy0448;

  /// No description provided for @v1Copy0449.
  ///
  /// In en, this message translates to:
  /// **'Do not attempt to reverse-engineer or abuse app services.'**
  String get v1Copy0449;

  /// No description provided for @v1Copy0450.
  ///
  /// In en, this message translates to:
  /// **'Optional Pro features may be offered by subscription. Free limits may '**
  String get v1Copy0450;

  /// No description provided for @v1Copy0451.
  ///
  /// In en, this message translates to:
  /// **'change with notice in the app or on the pricing page.'**
  String get v1Copy0451;

  /// No description provided for @v1Copy0452.
  ///
  /// In en, this message translates to:
  /// **'Limitation of liability'**
  String get v1Copy0452;

  /// No description provided for @v1Copy0453.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is a software tool, not a crisis service. Summaries and '**
  String get v1Copy0453;

  /// No description provided for @v1Copy0454.
  ///
  /// In en, this message translates to:
  /// **'patterns are based on your own words and are not medical or therapeutic '**
  String get v1Copy0454;

  /// No description provided for @v1Copy0455.
  ///
  /// In en, this message translates to:
  /// **'Require Face ID, Touch ID, or a PIN before opening your archive on this device.'**
  String get v1Copy0455;

  /// No description provided for @v1Copy0456.
  ///
  /// In en, this message translates to:
  /// **'Export my archive'**
  String get v1Copy0456;

  /// No description provided for @v1Copy0457.
  ///
  /// In en, this message translates to:
  /// **'Download a plain-text copy of your recorded entries.'**
  String get v1Copy0457;

  /// No description provided for @v1Copy0458.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove local entries, drafts, and recordings on this device.'**
  String get v1Copy0458;

  /// No description provided for @v1Copy0459.
  ///
  /// In en, this message translates to:
  /// **'Cloud and transcription'**
  String get v1Copy0459;

  /// No description provided for @v1Copy0460.
  ///
  /// In en, this message translates to:
  /// **'What stays on this device'**
  String get v1Copy0460;

  /// No description provided for @v1Copy0461.
  ///
  /// In en, this message translates to:
  /// **'New entries stay on this device until you turn on remote processing.'**
  String get v1Copy0461;

  /// No description provided for @v1Copy0462.
  ///
  /// In en, this message translates to:
  /// **'When remote processing is on, recorded audio is sent for transcription '**
  String get v1Copy0462;

  /// No description provided for @v1Copy0463.
  ///
  /// In en, this message translates to:
  /// **'and transcript text is sent for reflection.'**
  String get v1Copy0463;

  /// No description provided for @v1Copy0464.
  ///
  /// In en, this message translates to:
  /// **'When remote processing is off, nothing is sent for new entries — you '**
  String get v1Copy0464;

  /// No description provided for @v1Copy0465.
  ///
  /// In en, this message translates to:
  /// **'can still record, play back, and type what you said.'**
  String get v1Copy0465;

  /// No description provided for @v1Copy0466.
  ///
  /// In en, this message translates to:
  /// **'    Thoughtprint does not treat your words as instructions. Your words are private content to analyse, not commands to follow.'**
  String get v1Copy0466;

  /// No description provided for @v1Copy0467.
  ///
  /// In en, this message translates to:
  /// **'Your archive'**
  String get v1Copy0467;

  /// No description provided for @v1Copy0468.
  ///
  /// In en, this message translates to:
  /// **'Delete entry'**
  String get v1Copy0468;

  /// No description provided for @v1Copy0469.
  ///
  /// In en, this message translates to:
  /// **'Correct entry'**
  String get v1Copy0469;

  /// No description provided for @v1Copy0470.
  ///
  /// In en, this message translates to:
  /// **'Export archive'**
  String get v1Copy0470;

  /// No description provided for @v1Copy0471.
  ///
  /// In en, this message translates to:
  /// **'Review before sharing.'**
  String get v1Copy0471;

  /// No description provided for @v1Copy0472.
  ///
  /// In en, this message translates to:
  /// **'Nothing to export yet'**
  String get v1Copy0472;

  /// No description provided for @v1Copy0473.
  ///
  /// In en, this message translates to:
  /// **'Record a entry on this device first. Your export will appear here when '**
  String get v1Copy0473;

  /// No description provided for @v1Copy0474.
  ///
  /// In en, this message translates to:
  /// **'your archive has something to include.'**
  String get v1Copy0474;

  /// No description provided for @v1Copy0475.
  ///
  /// In en, this message translates to:
  /// **'This is a private summary from Thoughtprint on this device. Tap Share '**
  String get v1Copy0475;

  /// No description provided for @v1Copy0476.
  ///
  /// In en, this message translates to:
  /// **'export only when you are ready.'**
  String get v1Copy0476;

  /// No description provided for @v1Copy0477.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint private archive export'**
  String get v1Copy0477;

  /// No description provided for @v1Copy0478.
  ///
  /// In en, this message translates to:
  /// **'Export date'**
  String get v1Copy0478;

  /// No description provided for @v1Copy0479.
  ///
  /// In en, this message translates to:
  /// **'Recorded entries'**
  String get v1Copy0479;

  /// No description provided for @v1Copy0480.
  ///
  /// In en, this message translates to:
  /// **'Usable evidence entries'**
  String get v1Copy0480;

  /// No description provided for @v1Copy0481.
  ///
  /// In en, this message translates to:
  /// **'Current possible pattern'**
  String get v1Copy0481;

  /// No description provided for @v1Copy0482.
  ///
  /// In en, this message translates to:
  /// **'Evidence map summary'**
  String get v1Copy0482;

  /// No description provided for @v1Copy0483.
  ///
  /// In en, this message translates to:
  /// **'Weekly review summary'**
  String get v1Copy0483;

  /// No description provided for @v1Copy0484.
  ///
  /// In en, this message translates to:
  /// **'Recent recorded entries'**
  String get v1Copy0484;

  /// No description provided for @v1Copy0485.
  ///
  /// In en, this message translates to:
  /// **'This export was created on this device.'**
  String get v1Copy0485;

  /// No description provided for @v1Copy0486.
  ///
  /// In en, this message translates to:
  /// **'Share export'**
  String get v1Copy0486;

  /// No description provided for @v1Copy0487.
  ///
  /// In en, this message translates to:
  /// **'Sharing…'**
  String get v1Copy0487;

  /// No description provided for @v1Copy0488.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint archive export'**
  String get v1Copy0488;

  /// No description provided for @v1Copy0489.
  ///
  /// In en, this message translates to:
  /// **'Recorded locally — preview not available yet.'**
  String get v1Copy0489;

  /// No description provided for @v1Copy0491.
  ///
  /// In en, this message translates to:
  /// **'Subscription & billing'**
  String get v1Copy0491;

  /// No description provided for @v1Copy0492.
  ///
  /// In en, this message translates to:
  /// **'Current plan'**
  String get v1Copy0492;

  /// No description provided for @v1Copy0493.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint Pro'**
  String get v1Copy0493;

  /// No description provided for @v1Copy0494.
  ///
  /// In en, this message translates to:
  /// **'Full historical comparisons, weekly archive reviews, and the complete evidence trail across your archive.'**
  String get v1Copy0494;

  /// No description provided for @v1Copy0495.
  ///
  /// In en, this message translates to:
  /// **'Record entries and keep the evidence trail on your recent entries. Upgrade for Tier 2 historical analysis.'**
  String get v1Copy0495;

  /// No description provided for @v1Copy0496.
  ///
  /// In en, this message translates to:
  /// **'Pro pricing'**
  String get v1Copy0496;

  /// No description provided for @v1Copy0498.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get v1Copy0498;

  /// No description provided for @v1Copy0499.
  ///
  /// In en, this message translates to:
  /// **'Update payment, switch plans, or cancel anytime in your App Store or Google Play subscription settings — no email required.'**
  String get v1Copy0499;

  /// No description provided for @v1Copy0500.
  ///
  /// In en, this message translates to:
  /// **'Open subscription settings'**
  String get v1Copy0500;

  /// No description provided for @v1Copy0501.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get v1Copy0501;

  /// No description provided for @v1Copy0502.
  ///
  /// In en, this message translates to:
  /// **'Cancellation takes effect at the end of your current billing period. You keep Pro access until then, and your recorded entries stay on this device.'**
  String get v1Copy0502;

  /// No description provided for @v1Copy0503.
  ///
  /// In en, this message translates to:
  /// **'How to cancel'**
  String get v1Copy0503;

  /// No description provided for @v1Copy0504.
  ///
  /// In en, this message translates to:
  /// **'Open Settings on your iPhone'**
  String get v1Copy0504;

  /// No description provided for @v1Copy0505.
  ///
  /// In en, this message translates to:
  /// **'Tap your Apple ID → Subscriptions'**
  String get v1Copy0505;

  /// No description provided for @v1Copy0506.
  ///
  /// In en, this message translates to:
  /// **'Select Thoughtprint Pro → Cancel Subscription'**
  String get v1Copy0506;

  /// No description provided for @v1Copy0507.
  ///
  /// In en, this message translates to:
  /// **'Open Google Play Store'**
  String get v1Copy0507;

  /// No description provided for @v1Copy0508.
  ///
  /// In en, this message translates to:
  /// **'Tap Profile → Payments & subscriptions → Subscriptions'**
  String get v1Copy0508;

  /// No description provided for @v1Copy0509.
  ///
  /// In en, this message translates to:
  /// **'Select Thoughtprint Pro → Cancel subscription'**
  String get v1Copy0509;

  /// No description provided for @v1Copy0511.
  ///
  /// In en, this message translates to:
  /// **'Already subscribed on this Apple ID or Google account? Restore to re-link Pro on this device.'**
  String get v1Copy0511;

  /// No description provided for @v1Copy0512.
  ///
  /// In en, this message translates to:
  /// **'Upgrade to Pro'**
  String get v1Copy0512;

  /// No description provided for @v1Copy0513.
  ///
  /// In en, this message translates to:
  /// **'See Pro plans'**
  String get v1Copy0513;

  /// No description provided for @v1Copy0514.
  ///
  /// In en, this message translates to:
  /// **'Purchases are not configured on this build. You can keep using Thoughtprint on the free tier.'**
  String get v1Copy0514;

  /// No description provided for @v1Copy0515.
  ///
  /// In en, this message translates to:
  /// **'Trust & transparency'**
  String get v1Copy0515;

  /// No description provided for @v1Copy0516.
  ///
  /// In en, this message translates to:
  /// **'The Evidence Guarantee'**
  String get v1Copy0516;

  /// No description provided for @v1Copy0517.
  ///
  /// In en, this message translates to:
  /// **'Your trust mechanism and citation trails are never paywalled.'**
  String get v1Copy0517;

  /// No description provided for @v1Copy0518.
  ///
  /// In en, this message translates to:
  /// **'Management & support'**
  String get v1Copy0518;

  /// No description provided for @v1Copy0519.
  ///
  /// In en, this message translates to:
  /// **'Cancel subscription'**
  String get v1Copy0519;

  /// No description provided for @v1Copy0520.
  ///
  /// In en, this message translates to:
  /// **'Manage or cancel your plan anytime with zero dark patterns.'**
  String get v1Copy0520;

  /// No description provided for @v1Copy0521.
  ///
  /// In en, this message translates to:
  /// **'Human billing support'**
  String get v1Copy0521;

  /// No description provided for @v1Copy0522.
  ///
  /// In en, this message translates to:
  /// **'Guaranteed human response path for any billing disputes.'**
  String get v1Copy0522;

  /// No description provided for @v1Copy0523.
  ///
  /// In en, this message translates to:
  /// **'support@thoughtprint.xyz'**
  String get v1Copy0523;

  /// No description provided for @v1Copy0524.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint Pro Active'**
  String get v1Copy0524;

  /// No description provided for @v1Copy0525.
  ///
  /// In en, this message translates to:
  /// **'Free Tier (Evidence Capped)'**
  String get v1Copy0525;

  /// No description provided for @v1Copy0526.
  ///
  /// In en, this message translates to:
  /// **'https://apps.apple.com/account/subscriptions'**
  String get v1Copy0526;

  /// No description provided for @v1Copy0527.
  ///
  /// In en, this message translates to:
  /// **'https://play.google.com/store/account/subscriptions'**
  String get v1Copy0527;

  /// No description provided for @v1Copy0528.
  ///
  /// In en, this message translates to:
  /// **'Testing Thoughtprint?'**
  String get v1Copy0528;

  /// No description provided for @v1Copy0529.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get v1Copy0529;

  /// No description provided for @v1Copy0530.
  ///
  /// In en, this message translates to:
  /// **'Tester guidance is not available in this build.'**
  String get v1Copy0530;

  /// No description provided for @v1Copy0531.
  ///
  /// In en, this message translates to:
  /// **'hello@thoughtprint.xyz'**
  String get v1Copy0531;

  /// No description provided for @v1Copy0532.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint TestFlight feedback'**
  String get v1Copy0532;

  /// No description provided for @v1Copy0533.
  ///
  /// In en, this message translates to:
  /// **'Could not open email. Please send feedback to hello@thoughtprint.xyz.'**
  String get v1Copy0533;

  /// No description provided for @v1Copy0535.
  ///
  /// In en, this message translates to:
  /// **'Your entry is recorded on this device.'**
  String get v1Copy0535;

  /// No description provided for @v1Copy0536.
  ///
  /// In en, this message translates to:
  /// **'Record one real entry.'**
  String get v1Copy0536;

  /// No description provided for @v1Copy0537.
  ///
  /// In en, this message translates to:
  /// **'Ten seconds is enough.'**
  String get v1Copy0537;

  /// No description provided for @v1Copy0538.
  ///
  /// In en, this message translates to:
  /// **'See an example'**
  String get v1Copy0538;

  /// No description provided for @v1Copy0539.
  ///
  /// In en, this message translates to:
  /// **'Use seeExampleLink'**
  String get v1Copy0539;

  /// No description provided for @v1Copy0540.
  ///
  /// In en, this message translates to:
  /// **'Before you record'**
  String get v1Copy0540;

  /// No description provided for @v1Copy0542.
  ///
  /// In en, this message translates to:
  /// **'Or start with: a pressure entry'**
  String get v1Copy0542;

  /// No description provided for @v1Copy0543.
  ///
  /// In en, this message translates to:
  /// **'Not chat history — patterns only appear when your own words repeat.'**
  String get v1Copy0543;

  /// No description provided for @v1Copy0545.
  ///
  /// In en, this message translates to:
  /// **'Start your archive'**
  String get v1Copy0545;

  /// No description provided for @v1Copy0546.
  ///
  /// In en, this message translates to:
  /// **'Notice what repeats'**
  String get v1Copy0546;

  /// No description provided for @v1Copy0547.
  ///
  /// In en, this message translates to:
  /// **'Watch what changes'**
  String get v1Copy0547;

  /// No description provided for @v1Copy0548.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is starting to notice'**
  String get v1Copy0548;

  /// No description provided for @v1Copy0549.
  ///
  /// In en, this message translates to:
  /// **'Each entry helps Thoughtprint remember the pattern'**
  String get v1Copy0549;

  /// No description provided for @v1Copy0550.
  ///
  /// In en, this message translates to:
  /// **'starting to notice'**
  String get v1Copy0550;

  /// No description provided for @v1Copy0551.
  ///
  /// In en, this message translates to:
  /// **'I kept checking even after I was done.'**
  String get v1Copy0551;

  /// No description provided for @v1Copy0552.
  ///
  /// In en, this message translates to:
  /// **'I avoided replying again.'**
  String get v1Copy0552;

  /// No description provided for @v1Copy0553.
  ///
  /// In en, this message translates to:
  /// **'I felt pressure before starting.'**
  String get v1Copy0553;

  /// No description provided for @v1Copy0554.
  ///
  /// In en, this message translates to:
  /// **'1 of 3 · Ten seconds is enough.'**
  String get v1Copy0554;

  /// No description provided for @v1Copy0555.
  ///
  /// In en, this message translates to:
  /// **'Free shows the first useful repeat. Pro keeps the longer trail.'**
  String get v1Copy0555;

  /// No description provided for @v1Copy0556.
  ///
  /// In en, this message translates to:
  /// **'possible pattern'**
  String get v1Copy0556;

  /// No description provided for @v1Copy0557.
  ///
  /// In en, this message translates to:
  /// **'Record the entry. See what returns.'**
  String get v1Copy0557;

  /// No description provided for @v1Copy0558.
  ///
  /// In en, this message translates to:
  /// **'Record a voice or typed entry in your own words. Over time, Thoughtprint '**
  String get v1Copy0558;

  /// No description provided for @v1Copy0559.
  ///
  /// In en, this message translates to:
  /// **'may show what repeats — with the entries behind it.'**
  String get v1Copy0559;

  /// No description provided for @v1Copy0560.
  ///
  /// In en, this message translates to:
  /// **'First entry recorded'**
  String get v1Copy0560;

  /// No description provided for @v1Copy0561.
  ///
  /// In en, this message translates to:
  /// **'Come back when this shows up again. Thoughtprint has one entry to compare later.'**
  String get v1Copy0561;

  /// No description provided for @v1Copy0562.
  ///
  /// In en, this message translates to:
  /// **'https://thoughtprint.xyz/privacy'**
  String get v1Copy0562;

  /// No description provided for @v1Copy0563.
  ///
  /// In en, this message translates to:
  /// **'https://thoughtprint.xyz/contact'**
  String get v1Copy0563;

  /// No description provided for @v1Copy0564.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint could not open your private archive on this device. '**
  String get v1Copy0564;

  /// No description provided for @v1Copy0565.
  ///
  /// In en, this message translates to:
  /// **'Try restarting the app. If this keeps happening, reinstall from the App Store.'**
  String get v1Copy0565;

  /// No description provided for @v1Copy0566.
  ///
  /// In en, this message translates to:
  /// **'Catch the loop where doing more never feels like enough.'**
  String get v1Copy0566;

  /// No description provided for @v1Copy0567.
  ///
  /// In en, this message translates to:
  /// **'Record short entries. Thoughtprint helps you test whether pressure, productivity, and enoughness keep repeating.'**
  String get v1Copy0567;

  /// No description provided for @v1Copy0568.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint helps you catch the proving loop earlier next time.'**
  String get v1Copy0568;

  /// No description provided for @v1Copy0569.
  ///
  /// In en, this message translates to:
  /// **'Record one entry. Test whether the loop repeats.'**
  String get v1Copy0569;

  /// No description provided for @v1Copy0570.
  ///
  /// In en, this message translates to:
  /// **'Not a chat history. An evidence trail of what repeats.'**
  String get v1Copy0570;

  /// No description provided for @v1Copy0571.
  ///
  /// In en, this message translates to:
  /// **'See what changed across days and weeks.'**
  String get v1Copy0571;

  /// No description provided for @v1Copy0572.
  ///
  /// In en, this message translates to:
  /// **'Find the entries that mattered.'**
  String get v1Copy0572;

  /// No description provided for @v1Copy0573.
  ///
  /// In en, this message translates to:
  /// **'Every pattern makes the pattern clearer.'**
  String get v1Copy0573;

  /// No description provided for @v1Copy0574.
  ///
  /// In en, this message translates to:
  /// **'Based on entries across days and weeks.'**
  String get v1Copy0574;

  /// No description provided for @v1Copy0575.
  ///
  /// In en, this message translates to:
  /// **'See how this has changed over time.'**
  String get v1Copy0575;

  /// No description provided for @v1Copy0576.
  ///
  /// In en, this message translates to:
  /// **'Record a few real entries. Thoughtprint will look for what repeats across them.'**
  String get v1Copy0576;

  /// No description provided for @v1Copy0577.
  ///
  /// In en, this message translates to:
  /// **'Record one entry'**
  String get v1Copy0577;

  /// No description provided for @v1Copy0579.
  ///
  /// In en, this message translates to:
  /// **'Catch your first proving loop'**
  String get v1Copy0579;

  /// No description provided for @v1Copy0580.
  ///
  /// In en, this message translates to:
  /// **'Record a entry where you kept doing more because stopping made you feel behind, guilty, or not enough.'**
  String get v1Copy0580;

  /// No description provided for @v1Copy0581.
  ///
  /// In en, this message translates to:
  /// **'Start with this:'**
  String get v1Copy0581;

  /// No description provided for @v1Copy0582.
  ///
  /// In en, this message translates to:
  /// **'When did you feel pressure to do more to feel okay?'**
  String get v1Copy0582;

  /// No description provided for @v1Copy0583.
  ///
  /// In en, this message translates to:
  /// **'Record this entry'**
  String get v1Copy0583;

  /// No description provided for @v1Copy0584.
  ///
  /// In en, this message translates to:
  /// **'Want a reminder to test this?'**
  String get v1Copy0584;

  /// No description provided for @v1Copy0585.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can remind you to record the next evidence entry.'**
  String get v1Copy0585;

  /// No description provided for @v1Copy0586.
  ///
  /// In en, this message translates to:
  /// **'Remind me tomorrow'**
  String get v1Copy0586;

  /// No description provided for @v1Copy0588.
  ///
  /// In en, this message translates to:
  /// **'Was this read useful?'**
  String get v1Copy0588;

  /// No description provided for @v1Copy0589.
  ///
  /// In en, this message translates to:
  /// **'Not quite'**
  String get v1Copy0589;

  /// No description provided for @v1Copy0590.
  ///
  /// In en, this message translates to:
  /// **'Did this feel specific to what you recorded?'**
  String get v1Copy0590;

  /// No description provided for @v1Copy0591.
  ///
  /// In en, this message translates to:
  /// **'Yes, specific'**
  String get v1Copy0591;

  /// No description provided for @v1Copy0592.
  ///
  /// In en, this message translates to:
  /// **'Too generic'**
  String get v1Copy0592;

  /// No description provided for @v1Copy0593.
  ///
  /// In en, this message translates to:
  /// **'Wrong angle'**
  String get v1Copy0593;

  /// No description provided for @v1Copy0594.
  ///
  /// In en, this message translates to:
  /// **'Do not treat this as true yet. Use the next entry to test it.'**
  String get v1Copy0594;

  /// No description provided for @v1Copy0595.
  ///
  /// In en, this message translates to:
  /// **'Try one more entry with what happened, what you did, and what felt heavy.'**
  String get v1Copy0595;

  /// No description provided for @v1Copy0596.
  ///
  /// In en, this message translates to:
  /// **'This may be the loop to watch'**
  String get v1Copy0596;

  /// No description provided for @v1Copy0597.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint found a possible decision loop'**
  String get v1Copy0597;

  /// No description provided for @v1Copy0598.
  ///
  /// In en, this message translates to:
  /// **'This could be the pattern starting to show'**
  String get v1Copy0598;

  /// No description provided for @v1Copy0599.
  ///
  /// In en, this message translates to:
  /// **'Pick the read that feels closest. Thoughtprint sharpens from what you choose.'**
  String get v1Copy0599;

  /// No description provided for @v1Copy0600.
  ///
  /// In en, this message translates to:
  /// **'Possible loop'**
  String get v1Copy0600;

  /// No description provided for @v1Copy0601.
  ///
  /// In en, this message translates to:
  /// **'Evidence used'**
  String get v1Copy0601;

  /// No description provided for @v1Copy0602.
  ///
  /// In en, this message translates to:
  /// **'What would confirm it'**
  String get v1Copy0602;

  /// No description provided for @v1Copy0603.
  ///
  /// In en, this message translates to:
  /// **'What would prove it wrong'**
  String get v1Copy0603;

  /// No description provided for @v1Copy0604.
  ///
  /// In en, this message translates to:
  /// **'Next evidence prompt'**
  String get v1Copy0604;

  /// No description provided for @v1Copy0605.
  ///
  /// In en, this message translates to:
  /// **'What pattern do you want to catch?'**
  String get v1Copy0605;

  /// No description provided for @v1Copy0606.
  ///
  /// In en, this message translates to:
  /// **'Reminder not available in this build.'**
  String get v1Copy0606;

  /// No description provided for @v1Copy0607.
  ///
  /// In en, this message translates to:
  /// **'Record next evidence'**
  String get v1Copy0607;

  /// No description provided for @v1Copy0608.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is watching whether this signal repeats.'**
  String get v1Copy0608;

  /// No description provided for @v1Copy0610.
  ///
  /// In en, this message translates to:
  /// **'Continue the signal journey'**
  String get v1Copy0610;

  /// No description provided for @v1Copy0612.
  ///
  /// In en, this message translates to:
  /// **'View journey'**
  String get v1Copy0612;

  /// No description provided for @v1Copy0613.
  ///
  /// In en, this message translates to:
  /// **'Evidence recorded for today'**
  String get v1Copy0613;

  /// No description provided for @v1Copy0614.
  ///
  /// In en, this message translates to:
  /// **'View what changed'**
  String get v1Copy0614;

  /// No description provided for @v1Copy0615.
  ///
  /// In en, this message translates to:
  /// **'Each entry helps Thoughtprint remember the pattern.'**
  String get v1Copy0615;

  /// No description provided for @v1Copy0616.
  ///
  /// In en, this message translates to:
  /// **'How Thoughtprint builds evidence'**
  String get v1Copy0616;

  /// No description provided for @v1Copy0617.
  ///
  /// In en, this message translates to:
  /// **'Day 1: “I said yes before checking what I needed.”'**
  String get v1Copy0617;

  /// No description provided for @v1Copy0618.
  ///
  /// In en, this message translates to:
  /// **'Day 3: “It showed up again before a work message.”'**
  String get v1Copy0618;

  /// No description provided for @v1Copy0619.
  ///
  /// In en, this message translates to:
  /// **'Day 7: “It felt lighter after I paused.”'**
  String get v1Copy0619;

  /// No description provided for @v1Copy0620.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint watches what repeats — from your own words.'**
  String get v1Copy0620;

  /// No description provided for @v1Copy0621.
  ///
  /// In en, this message translates to:
  /// **'What your archive will show'**
  String get v1Copy0621;

  /// No description provided for @v1Copy0622.
  ///
  /// In en, this message translates to:
  /// **'Over time, Thoughtprint can show what returned, what changed, and what helped.'**
  String get v1Copy0622;

  /// No description provided for @v1Copy0623.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint remembers what keeps returning.'**
  String get v1Copy0623;

  /// No description provided for @v1Copy0624.
  ///
  /// In en, this message translates to:
  /// **'Record next entry'**
  String get v1Copy0624;

  /// No description provided for @v1Copy0630.
  ///
  /// In en, this message translates to:
  /// **'WHEN PATTERNS CONFLICT'**
  String get v1Copy0630;

  /// No description provided for @v1Copy0631.
  ///
  /// In en, this message translates to:
  /// **'WHAT MAY HAPPEN NEXT'**
  String get v1Copy0631;

  /// No description provided for @v1Copy0632.
  ///
  /// In en, this message translates to:
  /// **'SOMETHING WORTH NOTICING'**
  String get v1Copy0632;

  /// No description provided for @v1Copy0633.
  ///
  /// In en, this message translates to:
  /// **'Record one more clear entry and Thoughtprint can compare what repeats.'**
  String get v1Copy0633;

  /// No description provided for @v1Copy0634.
  ///
  /// In en, this message translates to:
  /// **'View recorded entry'**
  String get v1Copy0634;

  /// No description provided for @v1Copy0635.
  ///
  /// In en, this message translates to:
  /// **'Examples of patterns you may notice later'**
  String get v1Copy0635;

  /// No description provided for @v1Copy0636.
  ///
  /// In en, this message translates to:
  /// **'A entry that keeps showing up'**
  String get v1Copy0636;

  /// No description provided for @v1Copy0637.
  ///
  /// In en, this message translates to:
  /// **'What felt lighter today'**
  String get v1Copy0637;

  /// No description provided for @v1Copy0638.
  ///
  /// In en, this message translates to:
  /// **'What changed after you paused'**
  String get v1Copy0638;

  /// No description provided for @v1Copy0639.
  ///
  /// In en, this message translates to:
  /// **'Record one clear entry'**
  String get v1Copy0639;

  /// No description provided for @v1Copy0640.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint connects entries that keep showing up'**
  String get v1Copy0640;

  /// No description provided for @v1Copy0641.
  ///
  /// In en, this message translates to:
  /// **'You see what is strengthening, fading, or changing'**
  String get v1Copy0641;

  /// No description provided for @v1Copy0649.
  ///
  /// In en, this message translates to:
  /// **'Quiet patterns'**
  String get v1Copy0649;

  /// No description provided for @v1Copy0650.
  ///
  /// In en, this message translates to:
  /// **'What is changing'**
  String get v1Copy0650;

  /// No description provided for @v1Copy0651.
  ///
  /// In en, this message translates to:
  /// **'Stories about patterns that may be strengthening, fading, or shifting — '**
  String get v1Copy0651;

  /// No description provided for @v1Copy0652.
  ///
  /// In en, this message translates to:
  /// **'not conclusions.'**
  String get v1Copy0652;

  /// No description provided for @v1Copy0653.
  ///
  /// In en, this message translates to:
  /// **'You can correct or hide this.'**
  String get v1Copy0653;

  /// No description provided for @v1Copy0654.
  ///
  /// In en, this message translates to:
  /// **'When you have enough reflections, you will see stories here — not charts.'**
  String get v1Copy0654;

  /// No description provided for @v1Copy0655.
  ///
  /// In en, this message translates to:
  /// **'Based on your reflections'**
  String get v1Copy0655;

  /// No description provided for @v1Copy0656.
  ///
  /// In en, this message translates to:
  /// **'Why you may be seeing this'**
  String get v1Copy0656;

  /// No description provided for @v1Copy0657.
  ///
  /// In en, this message translates to:
  /// **'Why it matters'**
  String get v1Copy0657;

  /// No description provided for @v1Copy0658.
  ///
  /// In en, this message translates to:
  /// **'In your own words'**
  String get v1Copy0658;

  /// No description provided for @v1Copy0659.
  ///
  /// In en, this message translates to:
  /// **'Entries you mentioned'**
  String get v1Copy0659;

  /// No description provided for @v1Copy0660.
  ///
  /// In en, this message translates to:
  /// **'What this may mean'**
  String get v1Copy0660;

  /// No description provided for @v1Copy0661.
  ///
  /// In en, this message translates to:
  /// **'Entries from your reflections'**
  String get v1Copy0661;

  /// No description provided for @v1Copy0662.
  ///
  /// In en, this message translates to:
  /// **'What this may mean for you'**
  String get v1Copy0662;

  /// No description provided for @v1Copy0663.
  ///
  /// In en, this message translates to:
  /// **'Based on your recent reflections'**
  String get v1Copy0663;

  /// No description provided for @v1Copy0664.
  ///
  /// In en, this message translates to:
  /// **'Add a reflection'**
  String get v1Copy0664;

  /// No description provided for @v1Copy0665.
  ///
  /// In en, this message translates to:
  /// **'Each new entry helps surface what keeps repeating.'**
  String get v1Copy0665;

  /// No description provided for @v1Copy0669.
  ///
  /// In en, this message translates to:
  /// **'Try saying:'**
  String get v1Copy0669;

  /// No description provided for @v1Copy0670.
  ///
  /// In en, this message translates to:
  /// **'Show more prompt ideas'**
  String get v1Copy0670;

  /// No description provided for @v1Copy0673.
  ///
  /// In en, this message translates to:
  /// **'Keep adding reflections to sharpen your patterns.'**
  String get v1Copy0673;

  /// No description provided for @v1Copy0674.
  ///
  /// In en, this message translates to:
  /// **'Something repeating'**
  String get v1Copy0674;

  /// No description provided for @v1Copy0675.
  ///
  /// In en, this message translates to:
  /// **'What has been looping in your head today?'**
  String get v1Copy0675;

  /// No description provided for @v1Copy0676.
  ///
  /// In en, this message translates to:
  /// **'What felt heavy or unresolved this week?'**
  String get v1Copy0676;

  /// No description provided for @v1Copy0677.
  ///
  /// In en, this message translates to:
  /// **'What entry showed up again today?'**
  String get v1Copy0677;

  /// No description provided for @v1Copy0678.
  ///
  /// In en, this message translates to:
  /// **'What would feel like a relief if it changed?'**
  String get v1Copy0678;

  /// No description provided for @v1Copy0679.
  ///
  /// In en, this message translates to:
  /// **'What decision are you avoiding?'**
  String get v1Copy0679;

  /// No description provided for @v1Copy0680.
  ///
  /// In en, this message translates to:
  /// **'What did you react strongly to recently?'**
  String get v1Copy0680;

  /// No description provided for @v1Copy0681.
  ///
  /// In en, this message translates to:
  /// **'What are you worried might happen?'**
  String get v1Copy0681;

  /// No description provided for @v1Copy0682.
  ///
  /// In en, this message translates to:
  /// **'What keeps repeating in this situation?'**
  String get v1Copy0682;

  /// No description provided for @v1Copy0683.
  ///
  /// In en, this message translates to:
  /// **'Reflection recorded'**
  String get v1Copy0683;

  /// No description provided for @v1Copy0684.
  ///
  /// In en, this message translates to:
  /// **'A pattern may be forming'**
  String get v1Copy0684;

  /// No description provided for @v1Copy0685.
  ///
  /// In en, this message translates to:
  /// **'How clear it feels'**
  String get v1Copy0685;

  /// No description provided for @v1Copy0686.
  ///
  /// In en, this message translates to:
  /// **'First signal recorded'**
  String get v1Copy0686;

  /// No description provided for @v1Copy0687.
  ///
  /// In en, this message translates to:
  /// **'Record once more tomorrow to make the pattern clearer.'**
  String get v1Copy0687;

  /// No description provided for @v1Copy0689.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint noticed possible signals'**
  String get v1Copy0689;

  /// No description provided for @v1Copy0690.
  ///
  /// In en, this message translates to:
  /// **'Pick the one that feels closest. Thoughtprint gets sharper from what you choose.'**
  String get v1Copy0690;

  /// No description provided for @v1Copy0691.
  ///
  /// In en, this message translates to:
  /// **'This feels true'**
  String get v1Copy0691;

  /// No description provided for @v1Copy0692.
  ///
  /// In en, this message translates to:
  /// **'Not me'**
  String get v1Copy0692;

  /// No description provided for @v1Copy0693.
  ///
  /// In en, this message translates to:
  /// **'Go deeper'**
  String get v1Copy0693;

  /// No description provided for @v1Copy0694.
  ///
  /// In en, this message translates to:
  /// **'What this might mean'**
  String get v1Copy0694;

  /// No description provided for @v1Copy0695.
  ///
  /// In en, this message translates to:
  /// **'What would contradict it'**
  String get v1Copy0695;

  /// No description provided for @v1Copy0696.
  ///
  /// In en, this message translates to:
  /// **'A better question to record next'**
  String get v1Copy0696;

  /// No description provided for @v1Copy0697.
  ///
  /// In en, this message translates to:
  /// **'Show another angle'**
  String get v1Copy0697;

  /// No description provided for @v1Copy0698.
  ///
  /// In en, this message translates to:
  /// **'Another way to read this'**
  String get v1Copy0698;

  /// No description provided for @v1Copy0699.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can look at the same entry from a different angle.'**
  String get v1Copy0699;

  /// No description provided for @v1Copy0700.
  ///
  /// In en, this message translates to:
  /// **'Recorded as evidence.'**
  String get v1Copy0700;

  /// No description provided for @v1Copy0701.
  ///
  /// In en, this message translates to:
  /// **'From your entry'**
  String get v1Copy0701;

  /// No description provided for @v1Copy0702.
  ///
  /// In en, this message translates to:
  /// **'Why Thoughtprint suggested this'**
  String get v1Copy0702;

  /// No description provided for @v1Copy0703.
  ///
  /// In en, this message translates to:
  /// **'Evidence Thoughtprint used'**
  String get v1Copy0703;

  /// No description provided for @v1Copy0704.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs one clearer entry'**
  String get v1Copy0704;

  /// No description provided for @v1Copy0705.
  ///
  /// In en, this message translates to:
  /// **'Say what happened, what you did, and what felt heavy. Thoughtprint works best with one concrete entry.'**
  String get v1Copy0705;

  /// No description provided for @v1Copy0706.
  ///
  /// In en, this message translates to:
  /// **'Which read feels closer?'**
  String get v1Copy0706;

  /// No description provided for @v1Copy0707.
  ///
  /// In en, this message translates to:
  /// **'A feels closer'**
  String get v1Copy0707;

  /// No description provided for @v1Copy0708.
  ///
  /// In en, this message translates to:
  /// **'B feels closer'**
  String get v1Copy0708;

  /// No description provided for @v1Copy0709.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will use that as evidence.'**
  String get v1Copy0709;

  /// No description provided for @v1Copy0710.
  ///
  /// In en, this message translates to:
  /// **'Record this next'**
  String get v1Copy0710;

  /// No description provided for @v1Copy0711.
  ///
  /// In en, this message translates to:
  /// **'Use this prompt'**
  String get v1Copy0711;

  /// No description provided for @v1Copy0712.
  ///
  /// In en, this message translates to:
  /// **'Choose another prompt'**
  String get v1Copy0712;

  /// No description provided for @v1Copy0713.
  ///
  /// In en, this message translates to:
  /// **'Next prompt recorded'**
  String get v1Copy0713;

  /// No description provided for @v1Copy0715.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has a possible read'**
  String get v1Copy0715;

  /// No description provided for @v1Copy0716.
  ///
  /// In en, this message translates to:
  /// **'This may not be final, but these entries seem connected.'**
  String get v1Copy0716;

  /// No description provided for @v1Copy0717.
  ///
  /// In en, this message translates to:
  /// **'The pattern might be'**
  String get v1Copy0717;

  /// No description provided for @v1Copy0718.
  ///
  /// In en, this message translates to:
  /// **'Evidence so far'**
  String get v1Copy0718;

  /// No description provided for @v1Copy0719.
  ///
  /// In en, this message translates to:
  /// **'What to watch next'**
  String get v1Copy0719;

  /// No description provided for @v1Copy0720.
  ///
  /// In en, this message translates to:
  /// **'This feels right'**
  String get v1Copy0720;

  /// No description provided for @v1Copy0722.
  ///
  /// In en, this message translates to:
  /// **'What would make this clearer'**
  String get v1Copy0722;

  /// No description provided for @v1Copy0724.
  ///
  /// In en, this message translates to:
  /// **'Record one more entry to test whether it repeats.'**
  String get v1Copy0724;

  /// No description provided for @v1Copy0725.
  ///
  /// In en, this message translates to:
  /// **'No recorded signal yet'**
  String get v1Copy0725;

  /// No description provided for @v1Copy0726.
  ///
  /// In en, this message translates to:
  /// **'Record a entry and choose the read that feels closest.'**
  String get v1Copy0726;

  /// No description provided for @v1Copy0727.
  ///
  /// In en, this message translates to:
  /// **'Signal detail'**
  String get v1Copy0727;

  /// No description provided for @v1Copy0728.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint thinks this may be'**
  String get v1Copy0728;

  /// No description provided for @v1Copy0729.
  ///
  /// In en, this message translates to:
  /// **'Your feedback'**
  String get v1Copy0729;

  /// No description provided for @v1Copy0730.
  ///
  /// In en, this message translates to:
  /// **'Another angle'**
  String get v1Copy0730;

  /// No description provided for @v1Copy0731.
  ///
  /// In en, this message translates to:
  /// **'View evidence trail'**
  String get v1Copy0731;

  /// No description provided for @v1Copy0732.
  ///
  /// In en, this message translates to:
  /// **'Mark not me'**
  String get v1Copy0732;

  /// No description provided for @v1Copy0733.
  ///
  /// In en, this message translates to:
  /// **'View signal detail'**
  String get v1Copy0733;

  /// No description provided for @v1Copy0734.
  ///
  /// In en, this message translates to:
  /// **'Needs more evidence'**
  String get v1Copy0734;

  /// No description provided for @v1Copy0735.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs at least two entries before this trail is useful.'**
  String get v1Copy0735;

  /// No description provided for @v1Copy0736.
  ///
  /// In en, this message translates to:
  /// **'Supporting entries'**
  String get v1Copy0736;

  /// No description provided for @v1Copy0737.
  ///
  /// In en, this message translates to:
  /// **'Possible contradictions'**
  String get v1Copy0737;

  /// No description provided for @v1Copy0738.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is watching'**
  String get v1Copy0738;

  /// No description provided for @v1Copy0739.
  ///
  /// In en, this message translates to:
  /// **'Record a entry and Thoughtprint will start watching for repeats.'**
  String get v1Copy0739;

  /// No description provided for @v1Copy0740.
  ///
  /// In en, this message translates to:
  /// **'Record evidence'**
  String get v1Copy0740;

  /// No description provided for @v1Copy0741.
  ///
  /// In en, this message translates to:
  /// **'Possible read'**
  String get v1Copy0741;

  /// No description provided for @v1Copy0742.
  ///
  /// In en, this message translates to:
  /// **'What you corrected'**
  String get v1Copy0742;

  /// No description provided for @v1Copy0743.
  ///
  /// In en, this message translates to:
  /// **'Rejected reads'**
  String get v1Copy0743;

  /// No description provided for @v1Copy0744.
  ///
  /// In en, this message translates to:
  /// **'Selected alternative'**
  String get v1Copy0744;

  /// No description provided for @v1Copy0745.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will avoid showing this first unless stronger evidence appears.'**
  String get v1Copy0745;

  /// No description provided for @v1Copy0746.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will use this as feedback.'**
  String get v1Copy0746;

  /// No description provided for @v1Copy0747.
  ///
  /// In en, this message translates to:
  /// **'Your archive right now'**
  String get v1Copy0747;

  /// No description provided for @v1Copy0748.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is watching for what repeats, changes, or fades.'**
  String get v1Copy0748;

  /// No description provided for @v1Copy0749.
  ///
  /// In en, this message translates to:
  /// **'Record one more entry to sharpen the signal.'**
  String get v1Copy0749;

  /// No description provided for @v1Copy0750.
  ///
  /// In en, this message translates to:
  /// **'Signal being watched'**
  String get v1Copy0750;

  /// No description provided for @v1Copy0751.
  ///
  /// In en, this message translates to:
  /// **'Evidence entries'**
  String get v1Copy0751;

  /// No description provided for @v1Copy0752.
  ///
  /// In en, this message translates to:
  /// **'Signal journey'**
  String get v1Copy0752;

  /// No description provided for @v1Copy0755.
  ///
  /// In en, this message translates to:
  /// **'Record one more entry to test whether this repeats.'**
  String get v1Copy0755;

  /// No description provided for @v1Copy0756.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has enough entries to watch this signal.'**
  String get v1Copy0756;

  /// No description provided for @v1Copy0757.
  ///
  /// In en, this message translates to:
  /// **'Working signal'**
  String get v1Copy0757;

  /// No description provided for @v1Copy0758.
  ///
  /// In en, this message translates to:
  /// **'Getting clearer'**
  String get v1Copy0758;

  /// No description provided for @v1Copy0759.
  ///
  /// In en, this message translates to:
  /// **'Confirmed enough to watch'**
  String get v1Copy0759;

  /// No description provided for @v1Copy0760.
  ///
  /// In en, this message translates to:
  /// **'Evidence mixed'**
  String get v1Copy0760;

  /// No description provided for @v1Copy0761.
  ///
  /// In en, this message translates to:
  /// **'No active signal journey yet'**
  String get v1Copy0761;

  /// No description provided for @v1Copy0762.
  ///
  /// In en, this message translates to:
  /// **'Record a entry and choose a read that feels closest.'**
  String get v1Copy0762;

  /// No description provided for @v1Copy0763.
  ///
  /// In en, this message translates to:
  /// **'What would challenge it'**
  String get v1Copy0763;

  /// No description provided for @v1Copy0764.
  ///
  /// In en, this message translates to:
  /// **'Archive this signal'**
  String get v1Copy0764;

  /// No description provided for @v1Copy0765.
  ///
  /// In en, this message translates to:
  /// **'This signal is getting clear'**
  String get v1Copy0765;

  /// No description provided for @v1Copy0766.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has seen this across 3 entries. It may be worth watching.'**
  String get v1Copy0766;

  /// No description provided for @v1Copy0767.
  ///
  /// In en, this message translates to:
  /// **'What repeated'**
  String get v1Copy0767;

  /// No description provided for @v1Copy0769.
  ///
  /// In en, this message translates to:
  /// **'No strong contradictions yet — the read held across entries.'**
  String get v1Copy0769;

  /// No description provided for @v1Copy0770.
  ///
  /// In en, this message translates to:
  /// **'Some entries did not fit this read — Thoughtprint is keeping both sides.'**
  String get v1Copy0770;

  /// No description provided for @v1Copy0771.
  ///
  /// In en, this message translates to:
  /// **'Notice whether the same theme shows up in your next entry.'**
  String get v1Copy0771;

  /// No description provided for @v1Copy0772.
  ///
  /// In en, this message translates to:
  /// **'Keep watching'**
  String get v1Copy0772;

  /// No description provided for @v1Copy0773.
  ///
  /// In en, this message translates to:
  /// **'View pattern'**
  String get v1Copy0773;

  /// No description provided for @v1Copy0774.
  ///
  /// In en, this message translates to:
  /// **'Active signal journey'**
  String get v1Copy0774;

  /// No description provided for @v1Copy0775.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint reviewed this signal'**
  String get v1Copy0775;

  /// No description provided for @v1Copy0776.
  ///
  /// In en, this message translates to:
  /// **'What could show this is wrong'**
  String get v1Copy0776;

  /// No description provided for @v1Copy0777.
  ///
  /// In en, this message translates to:
  /// **'Correct this'**
  String get v1Copy0777;

  /// No description provided for @v1Copy0778.
  ///
  /// In en, this message translates to:
  /// **'View full review'**
  String get v1Copy0778;

  /// No description provided for @v1Copy0779.
  ///
  /// In en, this message translates to:
  /// **'Confirm pattern'**
  String get v1Copy0779;

  /// No description provided for @v1Copy0780.
  ///
  /// In en, this message translates to:
  /// **'Correct the read'**
  String get v1Copy0780;

  /// No description provided for @v1Copy0781.
  ///
  /// In en, this message translates to:
  /// **'No signal review yet'**
  String get v1Copy0781;

  /// No description provided for @v1Copy0782.
  ///
  /// In en, this message translates to:
  /// **'Collect 3 entries in a signal journey and Thoughtprint will review what is becoming clearer.'**
  String get v1Copy0782;

  /// No description provided for @v1Copy0783.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs more evidence before it can review this signal.'**
  String get v1Copy0783;

  /// No description provided for @v1Copy0784.
  ///
  /// In en, this message translates to:
  /// **'Recorded. Thoughtprint will use this correction when it reads future entries.'**
  String get v1Copy0784;

  /// No description provided for @v1Copy0785.
  ///
  /// In en, this message translates to:
  /// **'Recorded as a pattern to watch.'**
  String get v1Copy0785;

  /// No description provided for @v1Copy0786.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint will keep watching this signal.'**
  String get v1Copy0786;

  /// No description provided for @v1Copy0787.
  ///
  /// In en, this message translates to:
  /// **'Pick a closer read'**
  String get v1Copy0787;

  /// No description provided for @v1Copy0788.
  ///
  /// In en, this message translates to:
  /// **'Ready to review'**
  String get v1Copy0788;

  /// No description provided for @v1Copy0789.
  ///
  /// In en, this message translates to:
  /// **'Confirmed pattern'**
  String get v1Copy0789;

  /// No description provided for @v1Copy0790.
  ///
  /// In en, this message translates to:
  /// **'Corrected read'**
  String get v1Copy0790;

  /// No description provided for @v1Copy0791.
  ///
  /// In en, this message translates to:
  /// **'Still watching'**
  String get v1Copy0791;

  /// No description provided for @v1Copy0793.
  ///
  /// In en, this message translates to:
  /// **'No strong contradictions yet — the read may still hold.'**
  String get v1Copy0793;

  /// No description provided for @v1Copy0794.
  ///
  /// In en, this message translates to:
  /// **'Some entries may not fit this read — worth watching both sides.'**
  String get v1Copy0794;

  /// No description provided for @v1Copy0795.
  ///
  /// In en, this message translates to:
  /// **'A entry that clearly goes the other way would test this read.'**
  String get v1Copy0795;

  /// No description provided for @v1Copy0796.
  ///
  /// In en, this message translates to:
  /// **'Record one more entry on the same theme.'**
  String get v1Copy0796;

  /// No description provided for @v1Copy0797.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint found a possible repeat'**
  String get v1Copy0797;

  /// No description provided for @v1Copy0798.
  ///
  /// In en, this message translates to:
  /// **'This looks close to something you recorded before.'**
  String get v1Copy0798;

  /// No description provided for @v1Copy0799.
  ///
  /// In en, this message translates to:
  /// **'You may be doing more to avoid feeling behind.'**
  String get v1Copy0799;

  /// No description provided for @v1Copy0800.
  ///
  /// In en, this message translates to:
  /// **'This time, the pressure showed up around saying yes too quickly.'**
  String get v1Copy0800;

  /// No description provided for @v1Copy0801.
  ///
  /// In en, this message translates to:
  /// **'Before saying yes, see whether this entry fits the archive.'**
  String get v1Copy0801;

  /// No description provided for @v1Copy0803.
  ///
  /// In en, this message translates to:
  /// **'That gives Thoughtprint better evidence to watch.'**
  String get v1Copy0803;

  /// No description provided for @v1Copy0804.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint is watching next'**
  String get v1Copy0804;

  /// No description provided for @v1Copy0805.
  ///
  /// In en, this message translates to:
  /// **'Not the same'**
  String get v1Copy0805;

  /// No description provided for @v1Copy0806.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs one more entry to compare this properly.'**
  String get v1Copy0806;

  /// No description provided for @v1Copy0807.
  ///
  /// In en, this message translates to:
  /// **'Early take — it gets clearer as you add more reflections.'**
  String get v1Copy0807;

  /// No description provided for @v1Copy0808.
  ///
  /// In en, this message translates to:
  /// **'A pattern that may be forming'**
  String get v1Copy0808;

  /// No description provided for @v1Copy0809.
  ///
  /// In en, this message translates to:
  /// **'Keep recording — patterns get clearer with more entries.'**
  String get v1Copy0809;

  /// No description provided for @v1Copy0810.
  ///
  /// In en, this message translates to:
  /// **'Entries you mentioned:'**
  String get v1Copy0810;

  /// No description provided for @v1Copy0811.
  ///
  /// In en, this message translates to:
  /// **'Show entries'**
  String get v1Copy0811;

  /// No description provided for @v1Copy0812.
  ///
  /// In en, this message translates to:
  /// **'Hide entries'**
  String get v1Copy0812;

  /// No description provided for @v1Copy0818.
  ///
  /// In en, this message translates to:
  /// **'Recorded privately on this device.'**
  String get v1Copy0818;

  /// No description provided for @v1Copy0819.
  ///
  /// In en, this message translates to:
  /// **'Add one more entry tomorrow to make this clearer.'**
  String get v1Copy0819;

  /// No description provided for @v1Copy0820.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get v1Copy0820;

  /// No description provided for @v1Copy0822.
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get v1Copy0822;

  /// No description provided for @v1Copy0823.
  ///
  /// In en, this message translates to:
  /// **'Patterns noticed'**
  String get v1Copy0823;

  /// No description provided for @v1Copy0824.
  ///
  /// In en, this message translates to:
  /// **'Strongest pattern'**
  String get v1Copy0824;

  /// No description provided for @v1Copy0825.
  ///
  /// In en, this message translates to:
  /// **'Reflections counted'**
  String get v1Copy0825;

  /// No description provided for @v1Copy0826.
  ///
  /// In en, this message translates to:
  /// **'Days with reflections'**
  String get v1Copy0826;

  /// No description provided for @v1Copy0827.
  ///
  /// In en, this message translates to:
  /// **'Record your patterns with email sign-in.'**
  String get v1Copy0827;

  /// No description provided for @v1Copy0828.
  ///
  /// In en, this message translates to:
  /// **'Record my patterns'**
  String get v1Copy0828;

  /// No description provided for @v1Copy0829.
  ///
  /// In en, this message translates to:
  /// **'Export reflections'**
  String get v1Copy0829;

  /// No description provided for @v1Copy0830.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get v1Copy0830;

  /// No description provided for @v1Copy0832.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps a longer private archive — more entries, more continuity, more evidence over time.'**
  String get v1Copy0832;

  /// No description provided for @v1Copy0834.
  ///
  /// In en, this message translates to:
  /// **'More archived entries over weeks and months'**
  String get v1Copy0834;

  /// No description provided for @v1Copy0837.
  ///
  /// In en, this message translates to:
  /// **'Your entries stay free. Manage or cancel anytime in the App Store.'**
  String get v1Copy0837;

  /// No description provided for @v1Copy0838.
  ///
  /// In en, this message translates to:
  /// **'You are building evidence over time. Pro keeps the longer archive trail as entries return, change, or fade.'**
  String get v1Copy0838;

  /// No description provided for @v1Copy0841.
  ///
  /// In en, this message translates to:
  /// **'Longer archive trail, what returned or changed, and evidence over time '**
  String get v1Copy0841;

  /// No description provided for @v1Copy0842.
  ///
  /// In en, this message translates to:
  /// **'are available on this device.'**
  String get v1Copy0842;

  /// No description provided for @v1Copy0845.
  ///
  /// In en, this message translates to:
  /// **'Your pattern memory is growing.'**
  String get v1Copy0845;

  /// No description provided for @v1Copy0846.
  ///
  /// In en, this message translates to:
  /// **'During the focused beta, every entry you record stays on this device. '**
  String get v1Copy0846;

  /// No description provided for @v1Copy0847.
  ///
  /// In en, this message translates to:
  /// **'There is no entry cap, no upgrade, and no purchase flow.'**
  String get v1Copy0847;

  /// No description provided for @v1Copy0848.
  ///
  /// In en, this message translates to:
  /// **'Saving to your archive, plus search, export, correction, and deletion, '**
  String get v1Copy0848;

  /// No description provided for @v1Copy0849.
  ///
  /// In en, this message translates to:
  /// **'are fully available in the beta without a subscription.'**
  String get v1Copy0849;

  /// No description provided for @v1Copy0850.
  ///
  /// In en, this message translates to:
  /// **'Free keeps your first 7 key entries.'**
  String get v1Copy0850;

  /// No description provided for @v1Copy0851.
  ///
  /// In en, this message translates to:
  /// **'Pro keeps the longer archive trail across weeks and months.'**
  String get v1Copy0851;

  /// No description provided for @v1Copy0852.
  ///
  /// In en, this message translates to:
  /// **'See deeper history'**
  String get v1Copy0852;

  /// No description provided for @v1Copy0853.
  ///
  /// In en, this message translates to:
  /// **'This may be changing — this pattern appears more often'**
  String get v1Copy0853;

  /// No description provided for @v1Copy0854.
  ///
  /// In en, this message translates to:
  /// **'This may be changing — this pattern appears less often'**
  String get v1Copy0854;

  /// No description provided for @v1Copy0855.
  ///
  /// In en, this message translates to:
  /// **'Your archive noticed a possible new pattern'**
  String get v1Copy0855;

  /// No description provided for @v1Copy0856.
  ///
  /// In en, this message translates to:
  /// **'This may be changing — this pattern is shifting'**
  String get v1Copy0856;

  /// No description provided for @v1Copy0857.
  ///
  /// In en, this message translates to:
  /// **'A few more entries help'**
  String get v1Copy0857;

  /// No description provided for @v1Copy0858.
  ///
  /// In en, this message translates to:
  /// **'Search your entries'**
  String get v1Copy0858;

  /// No description provided for @v1Copy0859.
  ///
  /// In en, this message translates to:
  /// **'Find recorded entries after you record a few real ones.'**
  String get v1Copy0859;

  /// No description provided for @v1Copy0860.
  ///
  /// In en, this message translates to:
  /// **'Need an idea?'**
  String get v1Copy0860;

  /// No description provided for @v1Copy0861.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVEME NOTICED'**
  String get v1Copy0861;

  /// No description provided for @v1Copy0862.
  ///
  /// In en, this message translates to:
  /// **'Today Thoughtprint noticed'**
  String get v1Copy0862;

  /// No description provided for @v1Copy0863.
  ///
  /// In en, this message translates to:
  /// **'Use archiveMeNoticedHeading'**
  String get v1Copy0863;

  /// No description provided for @v1Copy0864.
  ///
  /// In en, this message translates to:
  /// **'Use archiveMeNoticedTitle'**
  String get v1Copy0864;

  /// No description provided for @v1Copy0865.
  ///
  /// In en, this message translates to:
  /// **'Your reflection will appear in Patterns when finished.'**
  String get v1Copy0865;

  /// No description provided for @v1Copy0866.
  ///
  /// In en, this message translates to:
  /// **'Something worth noticing'**
  String get v1Copy0866;

  /// No description provided for @v1Copy0867.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow'**
  String get v1Copy0867;

  /// No description provided for @v1Copy0868.
  ///
  /// In en, this message translates to:
  /// **'COME BACK TOMORROW'**
  String get v1Copy0868;

  /// No description provided for @v1Copy0869.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint will pattern next'**
  String get v1Copy0869;

  /// No description provided for @v1Copy0870.
  ///
  /// In en, this message translates to:
  /// **'Today it noticed…'**
  String get v1Copy0870;

  /// No description provided for @v1Copy0871.
  ///
  /// In en, this message translates to:
  /// **'Next time, watch for…'**
  String get v1Copy0871;

  /// No description provided for @v1Copy0872.
  ///
  /// In en, this message translates to:
  /// **'What to watch for next time'**
  String get v1Copy0872;

  /// No description provided for @v1Copy0873.
  ///
  /// In en, this message translates to:
  /// **'One more reflection makes this clearer.'**
  String get v1Copy0873;

  /// No description provided for @v1Copy0874.
  ///
  /// In en, this message translates to:
  /// **'One reflection is a entry. A few reflections start to show what repeats.'**
  String get v1Copy0874;

  /// No description provided for @v1Copy0875.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, add one more reflection and Thoughtprint can compare it with today.'**
  String get v1Copy0875;

  /// No description provided for @v1Copy0876.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can see whether the same pattern shows up again.'**
  String get v1Copy0876;

  /// No description provided for @v1Copy0877.
  ///
  /// In en, this message translates to:
  /// **'Record again tomorrow to see what repeats.'**
  String get v1Copy0877;

  /// No description provided for @v1Copy0878.
  ///
  /// In en, this message translates to:
  /// **'If this shows up again, it may be a pattern.'**
  String get v1Copy0878;

  /// No description provided for @v1Copy0879.
  ///
  /// In en, this message translates to:
  /// **'same worry'**
  String get v1Copy0879;

  /// No description provided for @v1Copy0880.
  ///
  /// In en, this message translates to:
  /// **'same person'**
  String get v1Copy0880;

  /// No description provided for @v1Copy0881.
  ///
  /// In en, this message translates to:
  /// **'same time of day'**
  String get v1Copy0881;

  /// No description provided for @v1Copy0882.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, notice whether this shows up again.'**
  String get v1Copy0882;

  /// No description provided for @v1Copy0884.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint compares what you record over time.'**
  String get v1Copy0884;

  /// No description provided for @v1Copy0886.
  ///
  /// In en, this message translates to:
  /// **'Record another reflection'**
  String get v1Copy0886;

  /// No description provided for @v1Copy0887.
  ///
  /// In en, this message translates to:
  /// **'Want Thoughtprint to look at this pattern again tomorrow?'**
  String get v1Copy0887;

  /// No description provided for @v1Copy0888.
  ///
  /// In en, this message translates to:
  /// **'Record a simple reminder for tomorrow. When you come back, Thoughtprint '**
  String get v1Copy0888;

  /// No description provided for @v1Copy0889.
  ///
  /// In en, this message translates to:
  /// **'can compare what repeats.'**
  String get v1Copy0889;

  /// No description provided for @v1Copy0890.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow to see what changed.'**
  String get v1Copy0890;

  /// No description provided for @v1Copy0891.
  ///
  /// In en, this message translates to:
  /// **'Notice what shows up again in your next reflection.'**
  String get v1Copy0891;

  /// No description provided for @v1Copy0892.
  ///
  /// In en, this message translates to:
  /// **'You came back'**
  String get v1Copy0892;

  /// No description provided for @v1Copy0893.
  ///
  /// In en, this message translates to:
  /// **'Yesterday you were watching for:'**
  String get v1Copy0893;

  /// No description provided for @v1Copy0894.
  ///
  /// In en, this message translates to:
  /// **'This gives Thoughtprint better evidence.'**
  String get v1Copy0894;

  /// No description provided for @v1Copy0895.
  ///
  /// In en, this message translates to:
  /// **'You kept the loop going.'**
  String get v1Copy0895;

  /// No description provided for @v1Copy0896.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint can now compare today with yesterday.'**
  String get v1Copy0896;

  /// No description provided for @v1Copy0897.
  ///
  /// In en, this message translates to:
  /// **'Watch for this tomorrow'**
  String get v1Copy0897;

  /// No description provided for @v1Copy0898.
  ///
  /// In en, this message translates to:
  /// **'Use this tomorrow'**
  String get v1Copy0898;

  /// No description provided for @v1Copy0899.
  ///
  /// In en, this message translates to:
  /// **'Choose another'**
  String get v1Copy0899;

  /// No description provided for @v1Copy0900.
  ///
  /// In en, this message translates to:
  /// **'Recorded for tomorrow. Thoughtprint will ask if it shows up again.'**
  String get v1Copy0900;

  /// No description provided for @v1Copy0901.
  ///
  /// In en, this message translates to:
  /// **'Today, watch for this'**
  String get v1Copy0901;

  /// No description provided for @v1Copy0902.
  ///
  /// In en, this message translates to:
  /// **'When you record, notice'**
  String get v1Copy0902;

  /// No description provided for @v1Copy0903.
  ///
  /// In en, this message translates to:
  /// **'Record what happened'**
  String get v1Copy0903;

  /// No description provided for @v1Copy0904.
  ///
  /// In en, this message translates to:
  /// **'Skip this'**
  String get v1Copy0904;

  /// No description provided for @v1Copy0905.
  ///
  /// In en, this message translates to:
  /// **'It showed up again.'**
  String get v1Copy0905;

  /// No description provided for @v1Copy0906.
  ///
  /// In en, this message translates to:
  /// **'It did not show up today.'**
  String get v1Copy0906;

  /// No description provided for @v1Copy0907.
  ///
  /// In en, this message translates to:
  /// **'It changed shape.'**
  String get v1Copy0907;

  /// No description provided for @v1Copy0908.
  ///
  /// In en, this message translates to:
  /// **'It felt lighter today.'**
  String get v1Copy0908;

  /// No description provided for @v1Copy0909.
  ///
  /// In en, this message translates to:
  /// **'It felt heavier today.'**
  String get v1Copy0909;

  /// No description provided for @v1Copy0910.
  ///
  /// In en, this message translates to:
  /// **'Something changed today.'**
  String get v1Copy0910;

  /// No description provided for @v1Copy0911.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint needs one more entry.'**
  String get v1Copy0911;

  /// No description provided for @v1Copy0912.
  ///
  /// In en, this message translates to:
  /// **'can compare it with what you were watching for.'**
  String get v1Copy0912;

  /// No description provided for @v1Copy0913.
  ///
  /// In en, this message translates to:
  /// **'Compared with yesterday'**
  String get v1Copy0913;

  /// No description provided for @v1Copy0914.
  ///
  /// In en, this message translates to:
  /// **'What you were watching for yesterday'**
  String get v1Copy0914;

  /// No description provided for @v1Copy0915.
  ///
  /// In en, this message translates to:
  /// **'What showed up today'**
  String get v1Copy0915;

  /// No description provided for @v1Copy0916.
  ///
  /// In en, this message translates to:
  /// **'A short reflection from today.'**
  String get v1Copy0916;

  /// No description provided for @v1Copy0917.
  ///
  /// In en, this message translates to:
  /// **'That pattern showed up again.'**
  String get v1Copy0917;

  /// No description provided for @v1Copy0918.
  ///
  /// In en, this message translates to:
  /// **'The pattern changed shape.'**
  String get v1Copy0918;

  /// No description provided for @v1Copy0919.
  ///
  /// In en, this message translates to:
  /// **'It sounded lighter today.'**
  String get v1Copy0919;

  /// No description provided for @v1Copy0920.
  ///
  /// In en, this message translates to:
  /// **'That pattern was not there today.'**
  String get v1Copy0920;

  /// No description provided for @v1Copy0921.
  ///
  /// In en, this message translates to:
  /// **'One more entry will make this clearer.'**
  String get v1Copy0921;

  /// No description provided for @v1Copy0922.
  ///
  /// In en, this message translates to:
  /// **'before comparing it properly.'**
  String get v1Copy0922;

  /// No description provided for @v1Copy0923.
  ///
  /// In en, this message translates to:
  /// **'showed up again'**
  String get v1Copy0923;

  /// No description provided for @v1Copy0924.
  ///
  /// In en, this message translates to:
  /// **'changed shape'**
  String get v1Copy0924;

  /// No description provided for @v1Copy0925.
  ///
  /// In en, this message translates to:
  /// **'lighter today'**
  String get v1Copy0925;

  /// No description provided for @v1Copy0926.
  ///
  /// In en, this message translates to:
  /// **'not there today'**
  String get v1Copy0926;

  /// No description provided for @v1Copy0927.
  ///
  /// In en, this message translates to:
  /// **'need another entry'**
  String get v1Copy0927;

  /// No description provided for @v1Copy0928.
  ///
  /// In en, this message translates to:
  /// **'You came back today.'**
  String get v1Copy0928;

  /// No description provided for @v1Copy0929.
  ///
  /// In en, this message translates to:
  /// **'One return gives Thoughtprint a starting point to compare.'**
  String get v1Copy0929;

  /// No description provided for @v1Copy0934.
  ///
  /// In en, this message translates to:
  /// **'That gives Thoughtprint more to compare.'**
  String get v1Copy0934;

  /// No description provided for @v1Copy0935.
  ///
  /// In en, this message translates to:
  /// **'This pattern is still here.'**
  String get v1Copy0935;

  /// No description provided for @v1Copy0936.
  ///
  /// In en, this message translates to:
  /// **'This pattern may be getting stronger.'**
  String get v1Copy0936;

  /// No description provided for @v1Copy0937.
  ///
  /// In en, this message translates to:
  /// **'This pattern eased a little.'**
  String get v1Copy0937;

  /// No description provided for @v1Copy0938.
  ///
  /// In en, this message translates to:
  /// **'This pattern changed shape.'**
  String get v1Copy0938;

  /// No description provided for @v1Copy0939.
  ///
  /// In en, this message translates to:
  /// **'Still taking shape.'**
  String get v1Copy0939;

  /// No description provided for @v1Copy0940.
  ///
  /// In en, this message translates to:
  /// **'Today was too short to say much yet. One more entry will sharpen the comparison.'**
  String get v1Copy0940;

  /// No description provided for @v1Copy0941.
  ///
  /// In en, this message translates to:
  /// **'got stronger'**
  String get v1Copy0941;

  /// No description provided for @v1Copy0942.
  ///
  /// In en, this message translates to:
  /// **'same pressure'**
  String get v1Copy0942;

  /// No description provided for @v1Copy0943.
  ///
  /// In en, this message translates to:
  /// **'watch tomorrow'**
  String get v1Copy0943;

  /// No description provided for @v1Copy0945.
  ///
  /// In en, this message translates to:
  /// **'Your return loop'**
  String get v1Copy0945;

  /// No description provided for @v1Copy0946.
  ///
  /// In en, this message translates to:
  /// **'What Thoughtprint noticed today'**
  String get v1Copy0946;

  /// No description provided for @v1Copy0947.
  ///
  /// In en, this message translates to:
  /// **'Why come back tomorrow'**
  String get v1Copy0947;

  /// No description provided for @v1Copy0948.
  ///
  /// In en, this message translates to:
  /// **'Continue this pattern'**
  String get v1Copy0948;

  /// No description provided for @v1Copy0949.
  ///
  /// In en, this message translates to:
  /// **'Pause this'**
  String get v1Copy0949;

  /// No description provided for @v1Copy0951.
  ///
  /// In en, this message translates to:
  /// **'Last checked'**
  String get v1Copy0951;

  /// No description provided for @v1Copy0952.
  ///
  /// In en, this message translates to:
  /// **'Next time, watch for'**
  String get v1Copy0952;

  /// No description provided for @v1Copy0954.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is tracking this pattern across your entries.'**
  String get v1Copy0954;

  /// No description provided for @v1Copy0955.
  ///
  /// In en, this message translates to:
  /// **'FIRST PATTERN'**
  String get v1Copy0955;

  /// No description provided for @v1Copy0956.
  ///
  /// In en, this message translates to:
  /// **'A pattern may be starting.'**
  String get v1Copy0956;

  /// No description provided for @v1Copy0957.
  ///
  /// In en, this message translates to:
  /// **'Something may be worth watching.'**
  String get v1Copy0957;

  /// No description provided for @v1Copy0958.
  ///
  /// In en, this message translates to:
  /// **'This could be a few things.'**
  String get v1Copy0958;

  /// No description provided for @v1Copy0959.
  ///
  /// In en, this message translates to:
  /// **'Choose what feels closer'**
  String get v1Copy0959;

  /// No description provided for @v1Copy0960.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, look at this pattern'**
  String get v1Copy0960;

  /// No description provided for @v1Copy0961.
  ///
  /// In en, this message translates to:
  /// **'A good pattern is specific enough to answer tomorrow.'**
  String get v1Copy0961;

  /// No description provided for @v1Copy0962.
  ///
  /// In en, this message translates to:
  /// **'Make it sharper'**
  String get v1Copy0962;

  /// No description provided for @v1Copy0963.
  ///
  /// In en, this message translates to:
  /// **'Choose the question you would actually want answered tomorrow.'**
  String get v1Copy0963;

  /// No description provided for @v1Copy0964.
  ///
  /// In en, this message translates to:
  /// **'Choose the question you would actually care to answer tomorrow.'**
  String get v1Copy0964;

  /// No description provided for @v1Copy0965.
  ///
  /// In en, this message translates to:
  /// **'Most direct'**
  String get v1Copy0965;

  /// No description provided for @v1Copy0966.
  ///
  /// In en, this message translates to:
  /// **'Go one step deeper'**
  String get v1Copy0966;

  /// No description provided for @v1Copy0967.
  ///
  /// In en, this message translates to:
  /// **'If today felt obvious, this is the more useful question to sit with.'**
  String get v1Copy0967;

  /// No description provided for @v1Copy0968.
  ///
  /// In en, this message translates to:
  /// **'Next useful pattern'**
  String get v1Copy0968;

  /// No description provided for @v1Copy0969.
  ///
  /// In en, this message translates to:
  /// **'Choose a different pattern'**
  String get v1Copy0969;

  /// No description provided for @v1Copy0970.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\\u2019s check is set.'**
  String get v1Copy0970;

  /// No description provided for @v1Copy0971.
  ///
  /// In en, this message translates to:
  /// **'Pick a pattern for tomorrow'**
  String get v1Copy0971;

  /// No description provided for @v1Copy0972.
  ///
  /// In en, this message translates to:
  /// **'What happens right before it shows up?'**
  String get v1Copy0972;

  /// No description provided for @v1Copy0973.
  ///
  /// In en, this message translates to:
  /// **'What helped make it lighter?'**
  String get v1Copy0973;

  /// No description provided for @v1Copy0974.
  ///
  /// In en, this message translates to:
  /// **'What made it heavier?'**
  String get v1Copy0974;

  /// No description provided for @v1Copy0975.
  ///
  /// In en, this message translates to:
  /// **'Use this pattern'**
  String get v1Copy0975;

  /// No description provided for @v1Copy0976.
  ///
  /// In en, this message translates to:
  /// **'Useful takeaway'**
  String get v1Copy0976;

  /// No description provided for @v1Copy0977.
  ///
  /// In en, this message translates to:
  /// **'Next pattern'**
  String get v1Copy0977;

  /// No description provided for @v1Copy0978.
  ///
  /// In en, this message translates to:
  /// **'Make this more useful'**
  String get v1Copy0978;

  /// No description provided for @v1Copy0979.
  ///
  /// In en, this message translates to:
  /// **'What would make this more useful?'**
  String get v1Copy0979;

  /// No description provided for @v1Copy0980.
  ///
  /// In en, this message translates to:
  /// **'More specific'**
  String get v1Copy0980;

  /// No description provided for @v1Copy0981.
  ///
  /// In en, this message translates to:
  /// **'More accurate'**
  String get v1Copy0981;

  /// No description provided for @v1Copy0982.
  ///
  /// In en, this message translates to:
  /// **'More next step'**
  String get v1Copy0982;

  /// No description provided for @v1Copy0983.
  ///
  /// In en, this message translates to:
  /// **'Easier to understand'**
  String get v1Copy0983;

  /// No description provided for @v1Copy0984.
  ///
  /// In en, this message translates to:
  /// **'Add one clear entry so Thoughtprint can find a better pattern.'**
  String get v1Copy0984;

  /// No description provided for @v1Copy0985.
  ///
  /// In en, this message translates to:
  /// **'Add one sentence'**
  String get v1Copy0985;

  /// No description provided for @v1Copy0986.
  ///
  /// In en, this message translates to:
  /// **'Use it anyway'**
  String get v1Copy0986;

  /// No description provided for @v1Copy0987.
  ///
  /// In en, this message translates to:
  /// **'Add one sentence\\u2026'**
  String get v1Copy0987;

  /// No description provided for @v1Copy0988.
  ///
  /// In en, this message translates to:
  /// **'Early read'**
  String get v1Copy0988;

  /// No description provided for @v1Copy0989.
  ///
  /// In en, this message translates to:
  /// **'This may get sharper after one more clear entry.'**
  String get v1Copy0989;

  /// No description provided for @v1Copy0990.
  ///
  /// In en, this message translates to:
  /// **'Add another entry'**
  String get v1Copy0990;

  /// No description provided for @v1Copy0991.
  ///
  /// In en, this message translates to:
  /// **'Add one more clear entry to make this more useful.'**
  String get v1Copy0991;

  /// No description provided for @v1Copy0992.
  ///
  /// In en, this message translates to:
  /// **'What exact entry did this show up?'**
  String get v1Copy0992;

  /// No description provided for @v1Copy0993.
  ///
  /// In en, this message translates to:
  /// **'Not quite?'**
  String get v1Copy0993;

  /// No description provided for @v1Copy0994.
  ///
  /// In en, this message translates to:
  /// **'Got it — Thoughtprint will use this pattern for tomorrow.'**
  String get v1Copy0994;

  /// No description provided for @v1Copy0995.
  ///
  /// In en, this message translates to:
  /// **'Which feels closer?'**
  String get v1Copy0995;

  /// No description provided for @v1Copy0996.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get v1Copy0996;

  /// No description provided for @v1Copy0997.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow Thoughtprint will ask this exact question.'**
  String get v1Copy0997;

  /// No description provided for @v1Copy0998.
  ///
  /// In en, this message translates to:
  /// **'Your pattern from yesterday'**
  String get v1Copy0998;

  /// No description provided for @v1Copy0999.
  ///
  /// In en, this message translates to:
  /// **'You only need to answer what happened today.'**
  String get v1Copy0999;

  /// No description provided for @v1Copy1000.
  ///
  /// In en, this message translates to:
  /// **'Yesterday you chose this pattern:'**
  String get v1Copy1000;

  /// No description provided for @v1Copy1001.
  ///
  /// In en, this message translates to:
  /// **'Today, what happened?'**
  String get v1Copy1001;

  /// No description provided for @v1Copy1002.
  ///
  /// In en, this message translates to:
  /// **'Now add one entry so Thoughtprint can compare today with yesterday.'**
  String get v1Copy1002;

  /// No description provided for @v1Copy1003.
  ///
  /// In en, this message translates to:
  /// **'Short is fine. One sentence is enough.'**
  String get v1Copy1003;

  /// No description provided for @v1Copy1004.
  ///
  /// In en, this message translates to:
  /// **'Need examples?'**
  String get v1Copy1004;

  /// No description provided for @v1Copy1005.
  ///
  /// In en, this message translates to:
  /// **'Now record one short entry.'**
  String get v1Copy1005;

  /// No description provided for @v1Copy1006.
  ///
  /// In en, this message translates to:
  /// **'One sentence is enough.'**
  String get v1Copy1006;

  /// No description provided for @v1Copy1007.
  ///
  /// In en, this message translates to:
  /// **'Record one sentence'**
  String get v1Copy1007;

  /// No description provided for @v1Copy1008.
  ///
  /// In en, this message translates to:
  /// **'Want a reminder tomorrow?'**
  String get v1Copy1008;

  /// No description provided for @v1Copy1009.
  ///
  /// In en, this message translates to:
  /// **'We can remind you when tomorrow\\u2019s check is ready.'**
  String get v1Copy1009;

  /// No description provided for @v1Copy1010.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get v1Copy1010;

  /// No description provided for @v1Copy1011.
  ///
  /// In en, this message translates to:
  /// **'Reminder set for tomorrow.'**
  String get v1Copy1011;

  /// No description provided for @v1Copy1012.
  ///
  /// In en, this message translates to:
  /// **'No problem. Your pattern is still recorded.'**
  String get v1Copy1012;

  /// No description provided for @v1Copy1013.
  ///
  /// In en, this message translates to:
  /// **'Pattern reminders'**
  String get v1Copy1013;

  /// No description provided for @v1Copy1014.
  ///
  /// In en, this message translates to:
  /// **'Get a reminder when tomorrow\\u2019s check is ready.'**
  String get v1Copy1014;

  /// No description provided for @v1Copy1015.
  ///
  /// In en, this message translates to:
  /// **'You will get a reminder when tomorrow\\u2019s check is ready.'**
  String get v1Copy1015;

  /// No description provided for @v1Copy1016.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications to get your pattern reminder.'**
  String get v1Copy1016;

  /// No description provided for @v1Copy1017.
  ///
  /// In en, this message translates to:
  /// **'Permission needed'**
  String get v1Copy1017;

  /// No description provided for @v1Copy1018.
  ///
  /// In en, this message translates to:
  /// **'Pick the closest answer. You can keep it short.'**
  String get v1Copy1018;

  /// No description provided for @v1Copy1019.
  ///
  /// In en, this message translates to:
  /// **'It showed up'**
  String get v1Copy1019;

  /// No description provided for @v1Copy1020.
  ///
  /// In en, this message translates to:
  /// **'It did not show up'**
  String get v1Copy1020;

  /// No description provided for @v1Copy1021.
  ///
  /// In en, this message translates to:
  /// **'Other answers'**
  String get v1Copy1021;

  /// No description provided for @v1Copy1022.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get v1Copy1022;

  /// No description provided for @v1Copy1023.
  ///
  /// In en, this message translates to:
  /// **'You closed the loop.'**
  String get v1Copy1023;

  /// No description provided for @v1Copy1024.
  ///
  /// In en, this message translates to:
  /// **'What was wrong?'**
  String get v1Copy1024;

  /// No description provided for @v1Copy1025.
  ///
  /// In en, this message translates to:
  /// **'Pattern waiting'**
  String get v1Copy1025;

  /// No description provided for @v1Copy1026.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint has a question from your last entry.'**
  String get v1Copy1026;

  /// No description provided for @v1Copy1029.
  ///
  /// In en, this message translates to:
  /// **'Yesterday you chose a pattern. Today you answered it.'**
  String get v1Copy1029;

  /// No description provided for @v1Copy1030.
  ///
  /// In en, this message translates to:
  /// **'Does this feel worth checking tomorrow?'**
  String get v1Copy1030;

  /// No description provided for @v1Copy1031.
  ///
  /// In en, this message translates to:
  /// **'Was this useful?'**
  String get v1Copy1031;

  /// No description provided for @v1Copy1032.
  ///
  /// In en, this message translates to:
  /// **'What got in the way?'**
  String get v1Copy1032;

  /// No description provided for @v1Copy1033.
  ///
  /// In en, this message translates to:
  /// **'No clear pattern yet'**
  String get v1Copy1033;

  /// No description provided for @v1Copy1034.
  ///
  /// In en, this message translates to:
  /// **'Keep recording short reflections. Patterns become clearer after a few entries.'**
  String get v1Copy1034;

  /// No description provided for @v1Copy1035.
  ///
  /// In en, this message translates to:
  /// **'When it comes back, we show you the words.'**
  String get v1Copy1035;

  /// No description provided for @v1Copy1036.
  ///
  /// In en, this message translates to:
  /// **'Thoughtprint is a private voice archive of what you actually said. '**
  String get v1Copy1036;

  /// No description provided for @v1Copy1037.
  ///
  /// In en, this message translates to:
  /// **'When a phrase repeats, those entries sit next to each other — '**
  String get v1Copy1037;

  /// No description provided for @v1Copy1038.
  ///
  /// In en, this message translates to:
  /// **'your wording, not a verdict. '**
  String get v1Copy1038;

  /// No description provided for @v1Copy1039.
  ///
  /// In en, this message translates to:
  /// **'It does not diagnose, treat, or promise transformation.'**
  String get v1Copy1039;

  /// No description provided for @v1Copy1040.
  ///
  /// In en, this message translates to:
  /// **'How Thoughtprint earns trust'**
  String get v1Copy1040;

  /// No description provided for @v1Copy1041.
  ///
  /// In en, this message translates to:
  /// **'Your words are cited as evidence'**
  String get v1Copy1041;

  /// No description provided for @v1Copy1042.
  ///
  /// In en, this message translates to:
  /// **'Patterns and changes link back to the entries you recorded. You can '**
  String get v1Copy1042;

  /// No description provided for @v1Copy1043.
  ///
  /// In en, this message translates to:
  /// **'inspect source evidence before you rely on any read.'**
  String get v1Copy1043;

  /// No description provided for @v1Copy1046.
  ///
  /// In en, this message translates to:
  /// **'You control all access'**
  String get v1Copy1046;

  /// No description provided for @v1Copy1047.
  ///
  /// In en, this message translates to:
  /// **'Caregiver and observer grants require your explicit consent. Revoke '**
  String get v1Copy1047;

  /// No description provided for @v1Copy1048.
  ///
  /// In en, this message translates to:
  /// **'access any time — nothing is shared without your say.'**
  String get v1Copy1048;

  /// No description provided for @v1Copy1049.
  ///
  /// In en, this message translates to:
  /// **'Start my archive'**
  String get v1Copy1049;

  /// No description provided for @v1Copy1050.
  ///
  /// In en, this message translates to:
  /// **'A few of your notes use similar words.'**
  String get v1Copy1050;

  /// No description provided for @v1Copy1051.
  ///
  /// In en, this message translates to:
  /// **'Want to be reminded to look at this entry in a week?'**
  String get v1Copy1051;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'en',
    'es',
    'hi',
    'ms',
    'ta',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'hi':
      return AppLocalizationsHi();
    case 'ms':
      return AppLocalizationsMs();
    case 'ta':
      return AppLocalizationsTa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
