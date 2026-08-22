import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:flutter/foundation.dart';

/// Gates the beta mission card to explicit TestFlight flags and developer unlock.
///
/// Production App Store release builds stay off unless
/// `--dart-define=ARCHIVEME_BETA_MISSION=true` is set at compile time.
abstract final class ArchiveBetaMissionGate {
  ArchiveBetaMissionGate._();

  static const _betaMissionFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_BETA_MISSION',
  );

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
  );

  @visibleForTesting
  static bool? enabledOverride;

  static bool get isEnabled {
    if (enabledOverride != null) return enabledOverride!;
    if (_releaseSmokeFromEnvironment) return false;
    if (_betaMissionFromEnvironment) return true;
    if (DeveloperSettingsGate.canShowDeveloperSettings) return true;
    return false;
  }

  static void disableForHarness() {
    enabledOverride = false;
  }

  static void resetPersistedState() {
    enabledOverride = null;
  }

  @visibleForTesting
  static void resetForTest() => resetPersistedState();
}