import 'package:meta/meta.dart';

/// Compile-time gate for the deferred insight-science / theory-tracking layer.
///
/// Default is off so V1 cold-start stability is unaffected. Enable locally with:
/// `--dart-define=VOICEMEMORY_ENABLE_THEORY_TRACKING=true`
abstract final class TheoryTrackingFeatureFlags {
  TheoryTrackingFeatureFlags._();

  static const bool _compileTimeDefault = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_THEORY_TRACKING',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  static bool get enableTheoryTracking =>
      debugOverride ?? _compileTimeDefault;
}