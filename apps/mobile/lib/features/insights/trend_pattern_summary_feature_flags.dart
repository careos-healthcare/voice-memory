import 'package:flutter/foundation.dart';

/// Compile-time gate for trend pattern summary surfaces.
///
/// Default is off. Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_TREND_PATTERN_SUMMARY=true`
abstract final class TrendPatternSummaryFeatureFlags {
  TrendPatternSummaryFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_TREND_PATTERN_SUMMARY',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get isEnabled => debugOverride ?? _compileTimeDefault;
}
