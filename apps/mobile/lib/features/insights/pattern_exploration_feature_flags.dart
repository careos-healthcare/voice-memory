import 'package:flutter/foundation.dart';

/// Compile-time gate for pattern exploration surfaces.
///
/// Default is off. Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_PATTERN_EXPLORATION=true`
abstract final class PatternExplorationFeatureFlags {
  PatternExplorationFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_PATTERN_EXPLORATION',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isEnabled => debugOverride ?? _compileTimeDefault;
}
