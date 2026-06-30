import 'package:flutter/foundation.dart';

/// Gates the beta mission card to debug IDE builds and explicit TestFlight flags.
///
/// Production App Store release builds stay off unless
/// `--dart-define=ARCHIVEME_BETA_MISSION=true` is set at compile time.
abstract final class ArchiveBetaMissionGate {
  ArchiveBetaMissionGate._();

  static const _betaMissionFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_BETA_MISSION',
    defaultValue: false,
  );

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  @visibleForTesting
  static bool? enabledOverride;

  static bool get isEnabled {
    if (enabledOverride != null) return enabledOverride!;
    if (_releaseSmokeFromEnvironment) return false;
    if (_betaMissionFromEnvironment) return true;
    if (kReleaseMode || kProfileMode) return false;
    return kDebugMode;
  }

  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
  }
}
