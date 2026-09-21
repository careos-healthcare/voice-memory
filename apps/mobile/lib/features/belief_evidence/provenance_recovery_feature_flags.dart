import 'package:flutter/foundation.dart';

/// Compile-time gate for provenance recovery surfaces.
///
/// Default is off. Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_PROVENANCE_RECOVERY=true`
abstract final class ProvenanceRecoveryFeatureFlags {
  ProvenanceRecoveryFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_PROVENANCE_RECOVERY',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isEnabled => debugOverride ?? _compileTimeDefault;
}
