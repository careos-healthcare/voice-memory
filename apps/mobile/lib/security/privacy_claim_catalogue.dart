import 'package:archiveme_mobile/security/privacy_copy_policy.dart';

/// Every trust and privacy claim ArchiveMe makes, stated once.
///
/// [PrivacyCopyPolicy] owns the *sensitive* promises and the rules that decide
/// whether a sentence is allowed to ship. This catalogue is the layer above it:
/// the place a claim is worded, so that a screen aliases a claim instead of
/// paraphrasing it. Copy classes should read like a list of references into
/// this file.
///
/// Why a catalogue and not just discipline: before it existed, one promise —
/// "storage protection is reported live rather than asserted" — was written
/// four different ways in four files, and the `/privacy` screen rendered two of
/// them a scroll apart. Nothing was wrong with any single wording. The failure
/// was that there were four, so correcting one corrected one.
///
/// Rules for adding to this file:
///
/// * a claim goes here when more than one surface makes it. A claim only one
///   screen makes stays on that screen;
/// * the wording must be checkable against code, and the doc comment must say
///   against what. If it cannot be checked, say less rather than hedging it;
/// * compose, do not paraphrase. Surfaces that need a longer sentence build it
///   out of these constants with interpolation, which is also what keeps the
///   duplicate-declaration gate quiet — see
///   `test/security/privacy_copy_duplication_test.dart`.
abstract final class PrivacyClaimCatalogue {
  PrivacyClaimCatalogue._();

  // ——— Headings ———

  /// Heading for the local-first architecture statement.
  ///
  /// Choice, not a processing mode: remote work is opt-in
  /// (`RemoteProcessingConsentStore`), so this heading must not read as
  /// "the AI already runs on the phone."
  ///
  /// Previously declared independently in
  /// `features/settings/ui/on_device_architecture_copy.dart` and
  /// `features/privacy/privacy_security_trust_copy.dart`.
  static const String onDeviceByDefaultHeading =
      'You choose what leaves your phone';

  /// Heading for the local-storage architecture block — not the send-choice
  /// heading above. The body lists what stays in local databases.
  static const String whatYouSaveStaysHereHeading = 'What you save stays here';

  /// Title of the archive privacy card.
  ///
  /// Previously declared independently in
  /// `security/archive_privacy_controls_copy.dart` and
  /// `features/trust/trust_reliability_copy.dart`.
  static const String archiveIsPrivateTitle = 'Your archive is private';

  /// The name of the privacy surface, wherever it is referred to.
  ///
  /// Previously declared independently in
  /// `features/privacy/privacy_security_trust_copy.dart` and
  /// `features/privacy/privacy_security_control_center_copy.dart`.
  static const String privacyAndSecurityTitle = 'Privacy & Security';

  // ——— Storage ———

  /// Where content sits when nothing has been sent.
  ///
  /// "Databases", plural, and no engine named: journal entries are an AES-GCM
  /// envelope written by `JournalStore` through `EncryptedJsonFileStore`, while
  /// the index that searches them is SQLCipher tables in `archiveme.db`. Naming
  /// either would misdescribe the other.
  static const String momentsStayLocal =
      'Your moments stay in local databases on this device.';

  /// Why this copy does not state a protection level.
  ///
  /// `SecureSqliteLockService.encryptionEnabled` is a runtime property of the
  /// build with an "unavailable" state, further gated on
  /// `Platform.isIOS || Platform.isAndroid` by
  /// `SqliteDatabaseInitializer.encryptionEnabled`. A fixed claim here would be
  /// false on some builds, so the copy points at the live report instead.
  ///
  /// Reads after [momentsStayLocal] or after any sentence that has just named
  /// what is stored — "them" takes its antecedent from there.
  ///
  /// Previously worded four different ways, in `trust_badge_copy.dart`,
  /// `on_device_architecture_copy.dart`, `onboarding_v1_copy.dart`, and
  /// `privacy_screen_copy.dart`.
  static const String storageProtectionReportedLive =
      'Privacy settings report how this build protects them, instead of '
      'asserting it here.';

  // ——— Remote processing ———

  /// The core promise: remote work happens because the user asked for it.
  ///
  /// Re-exported from [PrivacyCopyPolicy] rather than restated, because the
  /// policy is what the scanner reads.
  static const String remoteProcessingIsAChoice =
      PrivacyCopyPolicy.nothingSentUnlessFeatureChosen;

  /// What a choice actually buys, scoped to the job it was made for.
  ///
  /// `RemoteProcessingConsentGate` reads consent per request, and
  /// `CaptureProofAnalyzer.isPurposeGranted` grants transcription and
  /// reflection separately, so "for that job only" is enforced rather than
  /// promised.
  ///
  /// Previously worded three different ways, in `trust_badge_copy.dart`,
  /// `onboarding_v1_copy.dart`, and `on_device_architecture_copy.dart`.
  static const String remoteProcessingScopedToJob =
      'Choose transcription or sync and your audio and transcript text go to '
      'our servers for that job only.';

  /// Where the switch is, named so the claim can be checked.
  static const String remoteProcessingOffSwitch =
      'Turn it off in Settings → Privacy and new moments stay on this device.';

  // ——— Data controls ———

  /// Label for the destructive local wipe.
  ///
  /// Previously declared independently in `security/app_lock_settings.dart`
  /// and `security/security_settings_copy.dart`.
  static const String deleteAllLocalArchiveData =
      'Delete all local archive data';

  /// The phrase the user types to confirm that wipe.
  ///
  /// This one is load-bearing rather than merely tidy: `PrivateDataService`
  /// compares typed input against it and the settings screen renders it as the
  /// hint. Two copies that drift mean a confirmation field nothing can satisfy.
  static const String deleteArchiveConfirmationPhrase = 'DELETE MY ARCHIVE';

  /// Label for the non-destructive local clear, and for the button that
  /// confirms it.
  ///
  /// Previously declared independently in
  /// `security/account_privacy_controls_copy.dart` and twice in
  /// `security/privacy_data_controls_copy.dart`.
  static const String clearArchiveAction = 'Clear archive';

  /// Link out to the hosted policy.
  ///
  /// Previously declared independently in `product/consumer_ui_copy.dart` and
  /// `security/account_privacy_controls_copy.dart`.
  static const String privacyPolicyLink = 'Privacy policy';

  // ——— Confirmations ———

  /// Shown after a local wipe completes.
  ///
  /// Previously declared independently in
  /// `security/privacy_data_controls_copy.dart` and
  /// `features/privacy_trust/privacy_trust_copy.dart`.
  static const String localArchiveCleared = 'Local archive cleared.';

  /// Every claim in the catalogue, for gates and audits.
  static const List<String> all = [
    onDeviceByDefaultHeading,
    whatYouSaveStaysHereHeading,
    archiveIsPrivateTitle,
    privacyAndSecurityTitle,
    momentsStayLocal,
    storageProtectionReportedLive,
    remoteProcessingIsAChoice,
    remoteProcessingScopedToJob,
    remoteProcessingOffSwitch,
    deleteAllLocalArchiveData,
    deleteArchiveConfirmationPhrase,
    clearArchiveAction,
    privacyPolicyLink,
    localArchiveCleared,
  ];
}
