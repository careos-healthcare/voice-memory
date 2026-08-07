import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' as intl;

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

  /// A list of this localizations delegate.
  ///
  /// This app does not depend on `flutter_localizations`, so the
  /// `GlobalMaterialLocalizations`, `GlobalCupertinoLocalizations`, and
  /// `GlobalWidgetsLocalizations` delegates are not part of this list.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[delegate];

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
