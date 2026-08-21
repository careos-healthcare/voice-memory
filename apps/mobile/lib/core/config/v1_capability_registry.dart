import 'package:archiveme_mobile/core/config/v1_launch_product_contract.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_feature_flags.dart';
import 'package:archiveme_mobile/core/config/watch_companion_feature_flags.dart';

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

  static const bool notifications = false;
  static const bool backgroundProcessing = false;
  static const bool health = false;
  static const bool bluetooth = false;
  static const bool localNetwork = false;
  static const bool nearbyWifi = false;
  static const bool location = false;
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

  /// Apple Watch quick-record companion — see `docs/WATCHOS_SETUP.md`.
  static bool get watchCompanion => WatchCompanionFeatureFlags.enableWatchCompanion;

  static const Set<String> androidPermissionAllowlist = {
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.USE_BIOMETRIC',
  };

  static const Set<String> iosUsageDescriptionAllowlist = {
    'NSMicrophoneUsageDescription',
    'NSFaceIDUsageDescription',
    'NSSpeechRecognitionUsageDescription',
  };
}