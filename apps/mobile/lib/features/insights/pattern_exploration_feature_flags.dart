import 'package:flutter/foundation.dart';

/// Compile-time gate for pattern exploration surfaces.
///
/// On for this beta. Turn off with:
/// `--dart-define=VOICEMEMORY_ENABLE_PATTERN_EXPLORATION=false`
abstract final class PatternExplorationFeatureFlags {
  PatternExplorationFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_PATTERN_EXPLORATION',
    defaultValue: true,
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isEnabled => debugOverride ?? _compileTimeDefault;
}
