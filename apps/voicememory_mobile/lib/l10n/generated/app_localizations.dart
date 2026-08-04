import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @accountAuthCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your ArchiveMe account'**
  String get accountAuthCreateTitle;

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

  /// No description provided for @accountAuthSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to ArchiveMe'**
  String get accountAuthSignInTitle;

  /// No description provided for @accountAuthSignInCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get accountAuthSignInCta;

  /// No description provided for @accountAuthEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountAuthEmailLabel;

  /// No description provided for @accountAuthCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get accountAuthCodeTitle;

  /// No description provided for @accountAuthCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the sign-in code we just sent you.'**
  String get accountAuthCodeBody;

  /// No description provided for @accountAuthCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get accountAuthCodeLabel;

  /// No description provided for @accountAuthCodeCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get accountAuthCodeCta;

  /// No description provided for @accountAuthResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get accountAuthResendCode;

  /// No description provided for @accountAuthCodeSent.
  ///
  /// In en, this message translates to:
  /// **'Code sent — check your email.'**
  String get accountAuthCodeSent;

  /// No description provided for @accountAuthContinueWithoutAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue without an account'**
  String get accountAuthContinueWithoutAccount;

  /// No description provided for @accountAuthPrivacyLine.
  ///
  /// In en, this message translates to:
  /// **'Your archive stays private. We do not include your recordings in analytics.'**
  String get accountAuthPrivacyLine;

  /// No description provided for @accountAuthInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get accountAuthInvalidEmail;

  /// No description provided for @accountAuthInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your email.'**
  String get accountAuthInvalidCode;

  /// No description provided for @accountAuthSendCodeFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send the code.'**
  String get accountAuthSendCodeFailed;

  /// No description provided for @accountAuthSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Check the code and try again.'**
  String get accountAuthSignInFailed;

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

  /// No description provided for @authTriggerProtectArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Protect this archive'**
  String get authTriggerProtectArchiveTitle;

  /// No description provided for @authTriggerProtectArchiveLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in with email to encrypt a backup of what you built on this device.'**
  String get authTriggerProtectArchiveLead;

  /// No description provided for @authTriggerProtectArchiveCta.
  ///
  /// In en, this message translates to:
  /// **'Protect with email'**
  String get authTriggerProtectArchiveCta;

  /// No description provided for @authTriggerSyncArchiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your archive'**
  String get authTriggerSyncArchiveTitle;

  /// No description provided for @authTriggerSyncArchiveLead.
  ///
  /// In en, this message translates to:
  /// **'Email sign-in enables encrypted sync on this device.'**
  String get authTriggerSyncArchiveLead;

  /// No description provided for @authTriggerSyncArchiveCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync'**
  String get authTriggerSyncArchiveCta;

  /// No description provided for @authTriggerExportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export with a protected account'**
  String get authTriggerExportTitle;

  /// No description provided for @authTriggerExportLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in before exporting your archive.'**
  String get authTriggerExportLead;

  /// No description provided for @authTriggerExportCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to export'**
  String get authTriggerExportCta;

  /// No description provided for @authTriggerProPaywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in for Pro'**
  String get authTriggerProPaywallTitle;

  /// No description provided for @authTriggerProPaywallLead.
  ///
  /// In en, this message translates to:
  /// **'Checkout needs an account to protect your archive.'**
  String get authTriggerProPaywallLead;

  /// No description provided for @authTriggerProPaywallCta.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authTriggerProPaywallCta;

  /// No description provided for @authTriggerCrossDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue on another device'**
  String get authTriggerCrossDeviceTitle;

  /// No description provided for @authTriggerCrossDeviceLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to pick up your archive where you left off.'**
  String get authTriggerCrossDeviceLead;

  /// No description provided for @authTriggerCrossDeviceCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authTriggerCrossDeviceCta;

  /// No description provided for @authTriggerFirstWorkingBeliefTitle.
  ///
  /// In en, this message translates to:
  /// **'Your archive has a working belief'**
  String get authTriggerFirstWorkingBeliefTitle;

  /// No description provided for @authTriggerFirstWorkingBeliefLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to protect the belief your archive is forming.'**
  String get authTriggerFirstWorkingBeliefLead;

  /// No description provided for @authTriggerFirstWorkingBeliefCta.
  ///
  /// In en, this message translates to:
  /// **'Protect this belief'**
  String get authTriggerFirstWorkingBeliefCta;

  /// No description provided for @authTriggerArchiveChangedReturnTitle.
  ///
  /// In en, this message translates to:
  /// **'See what your archive believes now'**
  String get authTriggerArchiveChangedReturnTitle;

  /// No description provided for @authTriggerArchiveChangedReturnLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in to protect your archive after it may have shifted.'**
  String get authTriggerArchiveChangedReturnLead;

  /// No description provided for @authTriggerArchiveChangedReturnCta.
  ///
  /// In en, this message translates to:
  /// **'Protect archive'**
  String get authTriggerArchiveChangedReturnCta;

  /// No description provided for @authTriggerKeepTrackingProTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep tracking with Pro'**
  String get authTriggerKeepTrackingProTitle;

  /// No description provided for @authTriggerKeepTrackingProLead.
  ///
  /// In en, this message translates to:
  /// **'Sign in before upgrading so your archive stays backed up.'**
  String get authTriggerKeepTrackingProLead;

  /// No description provided for @authTriggerKeepTrackingProCta.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authTriggerKeepTrackingProCta;

  /// No description provided for @meshStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby encrypted sync'**
  String get meshStatusTitle;

  /// No description provided for @meshStatusSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching nearby'**
  String get meshStatusSearching;

  /// No description provided for @meshStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected securely'**
  String get meshStatusConnected;

  /// No description provided for @meshStatusComplete.
  ///
  /// In en, this message translates to:
  /// **'Local sync complete'**
  String get meshStatusComplete;

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

  /// No description provided for @meshSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync nearby'**
  String get meshSyncNow;

  /// No description provided for @meshShareCluster.
  ///
  /// In en, this message translates to:
  /// **'Share this cluster'**
  String get meshShareCluster;

  /// No description provided for @meshReadOnlyBranch.
  ///
  /// In en, this message translates to:
  /// **'Read-only shared branch'**
  String get meshReadOnlyBranch;

  /// No description provided for @meshPrivacyDescription.
  ///
  /// In en, this message translates to:
  /// **'Nearby discovery advertises only a rotating identifier. Archive metadata is exchanged after encrypted pairing.'**
  String get meshPrivacyDescription;

  /// No description provided for @primaryNavigationLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary navigation'**
  String get primaryNavigationLabel;

  /// No description provided for @recordScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Record screen'**
  String get recordScreenLabel;

  /// No description provided for @archiveScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Archive screen'**
  String get archiveScreenLabel;

  /// No description provided for @changesScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Changes screen'**
  String get changesScreenLabel;

  /// No description provided for @accountScreenLabel.
  ///
  /// In en, this message translates to:
  /// **'Account screen'**
  String get accountScreenLabel;

  /// No description provided for @navigationRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get navigationRecord;

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

  /// No description provided for @navigationAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navigationAccount;

  /// No description provided for @recordingStatus.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordingStatus;

  /// No description provided for @recordingInProgressSeconds.
  ///
  /// In en, this message translates to:
  /// **'Recording in progress, {seconds, plural, =1{1 second} other{{seconds} seconds}}'**
  String recordingInProgressSeconds(int seconds);

  /// No description provided for @recordingReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Ready to record'**
  String get recordingReadyStatus;

  /// No description provided for @recordingProcessingStatus.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordingProcessingStatus;

  /// No description provided for @recordingSavedStatus.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get recordingSavedStatus;

  /// No description provided for @recordingStopAndSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Tap Stop and save when you are finished.'**
  String get recordingStopAndSaveHint;

  /// No description provided for @recordingSavedBackgroundTranscription.
  ///
  /// In en, this message translates to:
  /// **'Recording saved. Transcription will finish in the background.'**
  String get recordingSavedBackgroundTranscription;

  /// No description provided for @recordingPromptNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your daily archive prompts improving'**
  String get recordingPromptNudgeTitle;

  /// No description provided for @recordingPromptNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe uses what you record to surface sharper things worth checking each day.'**
  String get recordingPromptNudgeBody;

  /// No description provided for @recordingUnlockPro.
  ///
  /// In en, this message translates to:
  /// **'Unlock Pro'**
  String get recordingUnlockPro;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @recordingPlainLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Say it plainly. ArchiveMe looks for patterns, not judgment.'**
  String get recordingPlainLanguageHint;

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

  /// No description provided for @savedForNextCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Saved for your next check-in.'**
  String get savedForNextCheckIn;

  /// No description provided for @savedForTomorrowCheck.
  ///
  /// In en, this message translates to:
  /// **'Saved for tomorrow\'s check.'**
  String get savedForTomorrowCheck;

  /// No description provided for @savedForNextMonthCheck.
  ///
  /// In en, this message translates to:
  /// **'Saved for next month\'s check.'**
  String get savedForNextMonthCheck;

  /// No description provided for @tomorrowCheckSet.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow\'s check is set.'**
  String get tomorrowCheckSet;

  /// No description provided for @recapCopied.
  ///
  /// In en, this message translates to:
  /// **'Recap copied.'**
  String get recapCopied;

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

  /// No description provided for @archiveEvidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get archiveEvidenceTitle;

  /// No description provided for @archiveNextStepsTitle.
  ///
  /// In en, this message translates to:
  /// **'Next steps'**
  String get archiveNextStepsTitle;

  /// No description provided for @archiveAddMoment.
  ///
  /// In en, this message translates to:
  /// **'Add a moment'**
  String get archiveAddMoment;

  /// No description provided for @archiveNeedsComparison.
  ///
  /// In en, this message translates to:
  /// **'Add another moment so ArchiveMe can compare what changed.'**
  String get archiveNeedsComparison;

  /// No description provided for @archiveCurrentObservation.
  ///
  /// In en, this message translates to:
  /// **'Your clearest current observation is: {statement}'**
  String archiveCurrentObservation(String statement);

  /// No description provided for @archiveNeedsSupportedMoments.
  ///
  /// In en, this message translates to:
  /// **'ArchiveMe needs at least two supported moments before explaining a pattern.'**
  String get archiveNeedsSupportedMoments;

  /// No description provided for @archiveEvidenceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved moment available for comparison.} other{{count} saved moments available for comparison.}}'**
  String archiveEvidenceCount(int count);

  /// No description provided for @archiveNextMomentGuidance.
  ///
  /// In en, this message translates to:
  /// **'Record or type one specific moment. A second supported observation makes change visible.'**
  String get archiveNextMomentGuidance;

  /// No description provided for @coachingInsightSemantics.
  ///
  /// In en, this message translates to:
  /// **'{category}. Confidence {percentage} percent. {content}'**
  String coachingInsightSemantics(
    String category,
    int percentage,
    String content,
  );

  /// No description provided for @coachingInsightHint.
  ///
  /// In en, this message translates to:
  /// **'AI-generated reflection based on recent journal evidence.'**
  String get coachingInsightHint;

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

  /// No description provided for @memoryGraphActionBarLabel.
  ///
  /// In en, this message translates to:
  /// **'Memory Graph actions'**
  String get memoryGraphActionBarLabel;

  /// No description provided for @memoryGraphActionBarHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe horizontally to explore more graph actions.'**
  String get memoryGraphActionBarHint;

  /// No description provided for @memoryGraphActionButtonHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to activate this graph action.'**
  String get memoryGraphActionButtonHint;

  /// No description provided for @memoryGraphNodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 node} other{{count} nodes}}'**
  String memoryGraphNodeCount(int count);

  /// No description provided for @memoryGraphLifeSimulator.
  ///
  /// In en, this message translates to:
  /// **'Life Simulator'**
  String get memoryGraphLifeSimulator;

  /// No description provided for @memoryGraphSmallSteps.
  ///
  /// In en, this message translates to:
  /// **'Small steps'**
  String get memoryGraphSmallSteps;

  /// No description provided for @memoryGraphWidgets.
  ///
  /// In en, this message translates to:
  /// **'Widgets'**
  String get memoryGraphWidgets;

  /// No description provided for @memoryGraphDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get memoryGraphDocuments;

  /// No description provided for @memoryGraphWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get memoryGraphWeekly;

  /// No description provided for @memoryGraphClusters.
  ///
  /// In en, this message translates to:
  /// **'Clusters {count}'**
  String memoryGraphClusters(int count);

  /// No description provided for @memoryGraphCloseRewind.
  ///
  /// In en, this message translates to:
  /// **'Close Rewind'**
  String get memoryGraphCloseRewind;

  /// No description provided for @memoryGraphTimeMachine.
  ///
  /// In en, this message translates to:
  /// **'Time Machine'**
  String get memoryGraphTimeMachine;

  /// No description provided for @memoryGraphLifeDashboard.
  ///
  /// In en, this message translates to:
  /// **'Life Dashboard'**
  String get memoryGraphLifeDashboard;

  /// No description provided for @memoryGraphClosePreview.
  ///
  /// In en, this message translates to:
  /// **'Close Preview'**
  String get memoryGraphClosePreview;

  /// No description provided for @memoryGraphPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview Graph'**
  String get memoryGraphPreview;

  /// No description provided for @memoryGraphSampleBadge.
  ///
  /// In en, this message translates to:
  /// **'Sample Mind · illustrative'**
  String get memoryGraphSampleBadge;

  /// No description provided for @memoryGraphReturnToPresent.
  ///
  /// In en, this message translates to:
  /// **'Return to Present'**
  String get memoryGraphReturnToPresent;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
