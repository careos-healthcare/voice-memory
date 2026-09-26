import 'package:archiveme_mobile/core/config/v1_launch_product_contract.dart';
import 'package:archiveme_mobile/core/config/watch_companion_feature_flags.dart';
import 'package:archiveme_mobile/features/belief_evidence/provenance_recovery_feature_flags.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/features/insights/pattern_exploration_feature_flags.dart';
import 'package:archiveme_mobile/features/insights/trend_pattern_summary_feature_flags.dart';

/// Launch-profile switches. Apple Health stays on for the beta so the
/// HealthKit share string and the mood sync control are both active.
abstract final class AppFlags {
  AppFlags._();

  static const bool appleHealth = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_APPLE_HEALTH',
    defaultValue: true,
  );

  /// Cited questions after a save. Off until the saved answers are reviewed.
  static const bool postSaveFollowUp = bool.fromEnvironment(
    'POST_SAVE_FOLLOW_UP',
  );
}

/// Compile-time native capability allowlist for the focused V1 release.
///
/// Keep this file aligned with `docs/V1_PERMISSION_MATRIX.md`, the nine launch
/// capabilities in [V1LaunchProductContract.launchCapabilities], the native
/// manifests, and `tool/audit_v1_permissions.sh`. Values are constants so
/// excluded startup branches are removed by release tree shaking.
abstract final class V1CapabilityRegistry {
  V1CapabilityRegistry._();

  /// Customer-facing launch capabilities — see `docs/V1_PRODUCT_CONTRACT.md`.
  static List<String> get launchCapabilityIds => [
    for (final capability in V1LaunchProductContract.launchCapabilities)
      capability.id,
  ];

  static const bool microphone = true;
  static const bool biometricLock = true;
  static const bool internet = true;
  static const bool storeBilling = false;

  static const bool notifications = true;
  static const bool backgroundProcessing = false;

  /// Apple Health State of Mind. Permission and the Settings control share
  /// [AppFlags.appleHealth].
  static const bool health = AppFlags.appleHealth;

  /// Settings control that reads Apple Health State of Mind.
  static const bool appleHealth = AppFlags.appleHealth;

  /// Passphrase-sealed journal sync in Settings. Off until reviewed.
  static const bool e2eeSync = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_E2EE_SYNC',
    defaultValue: false,
  );

  /// Share-sheet and Open In import of Apple Voice Memos. Off until reviewed.
  static const bool voiceMemosImport = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_VOICE_MEMOS_IMPORT',
    defaultValue: false,
  );

  /// Photo attachments and image evidence. Off until reviewed.
  static const bool photoAttachments = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_PHOTO_ATTACHMENTS',
    defaultValue: false,
  );
  static const bool bluetooth = false;
  static const bool localNetwork = false;
  static const bool nearbyWifi = false;

  /// When-in-use place lookup. Beta builds turn this on from
  /// `config/launch_profile.json` (`VOICEMEMORY_ENABLE_LOCATION`).
  static const bool location = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_LOCATION',
    defaultValue: true,
  );
  static const bool calendar = false;
  static const bool cameraAndPhotos = false;
  static const bool activityRecognition = false;
  static const bool speechRecognition = true;
  static const bool p2pAndWebRtc = false;

  /// MCP calendar/health connectors and similar OS data bridges.
  static const bool externalDataConnectors = false;
  static const bool nativeExtensions = false;
  static const bool liveVoice = false;

  /// On-device-only AI privacy controls in Settings (never-send-to-server gate).
  static const bool localAiPrivacyControls = true;

  /// Caregiver monitoring — see `docs/CAREGIVER_MONITORING.md`.
  static bool get caregiverMonitoring =>
      CaregiverFeatureFlags.isCaregiverModeEnabled;

  /// Pattern exploration — compile-time gated.
  static bool get patternExploration =>
      PatternExplorationFeatureFlags.isEnabled;

  /// Trend pattern summary — compile-time gated.
  static bool get trendPatternSummary =>
      TrendPatternSummaryFeatureFlags.isEnabled;

  /// Provenance recovery — compile-time gated.
  static bool get provenanceRecovery =>
      ProvenanceRecoveryFeatureFlags.isEnabled;

  /// Apple Watch quick-record companion — see `docs/WATCHOS_SETUP.md`.
  static bool get watchCompanion =>
      WatchCompanionFeatureFlags.enableWatchCompanion;

  /// Second onboarding screen offers the existing notes importer.
  /// Left off until reviewed.
  static const bool onboardingImportFirst = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_ONBOARDING_IMPORT_FIRST',
    defaultValue: false,
  );

  /// After the first save, quote the recording back with no interpretation.
  /// Left off until reviewed.
  static const bool firstSaveQuoteBack = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_FIRST_SAVE_QUOTE_BACK',
    defaultValue: false,
  );

  /// Home Screen widget, Lock Screen widget, Siri shortcut, Control Center,
  /// Action Button, and Live Activity. The Watch companion is
  /// [watchCompanion], which stays off. The older Today extension is
  /// [nativeExtensions], which stays off.
  static const bool nativeQuickCapture = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_NATIVE_QUICK_CAPTURE',
    defaultValue: false,
  );

  /// Passphrase-sealed archive backup to iCloud or a user-picked drive file.
  /// Left off until reviewed.
  static const bool encryptedBackup = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_ENCRYPTED_BACKUP',
    defaultValue: false,
  );

  /// Optional local reminders: daily nudge, on this day, and check back.
  /// Left off until reviewed. No server push.
  static const bool gentleReminders = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_GENTLE_REMINDERS',
    defaultValue: false,
  );

  /// On-device partial transcript while recording. Display only.
  /// The saved transcript still comes from the final pipeline.
  /// Left off until reviewed.
  static const bool liveDraftTranscript = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_LIVE_DRAFT_TRANSCRIPT',
    defaultValue: false,
  );

  /// Cited questions after a save. Off until the saved answers are reviewed.
  static const bool postSaveFollowUp = AppFlags.postSaveFollowUp;

  /// Sunday/Monday archive recap. Off until the copy is reviewed.
  static const bool weeklyRecapBanner = bool.fromEnvironment(
    'WEEKLY_RECAP_BANNER',
    defaultValue: false,
  );

  /// On This Day, calendar, map, and printable journal on the Archive tab.
  static const bool enableHistoryViews = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_HISTORY_VIEWS',
    defaultValue: true,
  );

  static const Set<String> androidPermissionAllowlist = {
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.USE_BIOMETRIC',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.RECEIVE_BOOT_COMPLETED',
  };

  static const Set<String> iosUsageDescriptionAllowlist = {
    'NSMicrophoneUsageDescription',
    'NSFaceIDUsageDescription',
    'NSSpeechRecognitionUsageDescription',
  };
}
