import 'package:meta/meta.dart';

/// Compile-time gate for caregiver monitoring surfaces.
///
/// Default is off until monitoring ships with server consent verification.
/// Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_CAREGIVER_MODE=true`
///
/// Registry: [V1CapabilityRegistry.caregiverMonitoring].
/// Governance: `docs/CAREGIVER_MONITORING.md`.
abstract final class CaregiverFeatureFlags {
  CaregiverFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_CAREGIVER_MODE',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isCaregiverModeEnabled =>
      debugOverride ?? _compileTimeDefault;
}