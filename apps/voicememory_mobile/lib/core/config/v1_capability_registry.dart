/// Compile-time native capability allowlist for the focused V1 release.
///
/// Keep this file aligned with `docs/V1_PERMISSION_MATRIX.md`, the native
/// manifests, and `tool/audit_v1_permissions.sh`. Values are constants so
/// excluded startup branches are removed by release tree shaking.
abstract final class V1CapabilityRegistry {
  V1CapabilityRegistry._();

  static const bool microphone = true;
  static const bool biometricLock = true;
  static const bool internet = true;
  static const bool storeBilling = true;

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
  static const bool speechRecognition = false;
  static const bool p2pAndWebRtc = false;
  static const bool externalDataConnectors = false;
  static const bool nativeExtensions = false;
  static const bool liveVoice = false;

  static const Set<String> androidPermissionAllowlist = {
    'android.permission.INTERNET',
    'android.permission.RECORD_AUDIO',
    'android.permission.USE_BIOMETRIC',
    'com.android.vending.BILLING',
  };

  static const Set<String> iosUsageDescriptionAllowlist = {
    'NSMicrophoneUsageDescription',
    'NSFaceIDUsageDescription',
  };
}
