import 'package:flutter/foundation.dart';

/// Compile-time gate for the clinical-signal sandbox (SaMD-regulated layer).
///
/// Requires **all** of the following to activate:
/// 1. `--dart-define=VOICEMEMORY_ENABLE_CLINICAL_SANDBOX=true`
/// 2. `--dart-define=VOICEMEMORY_CLINICAL_SANDBOX_DEV_TOKEN=<non-empty secret>`
/// 3. Debug/profile build **or**
///    `--dart-define=VOICEMEMORY_CLINICAL_SANDBOX_INTERNAL_BUILD=true`
///
/// Default is off so public distribution builds never run biomarker analysis.
abstract final class ClinicalSandboxFeatureFlags {
  ClinicalSandboxFeatureFlags._();

  static const bool _compileTimeEnabled = bool.fromEnvironment(
    'VOICEMEMORY_ENABLE_CLINICAL_SANDBOX',
  );

  static const String _devToken = String.fromEnvironment(
    'VOICEMEMORY_CLINICAL_SANDBOX_DEV_TOKEN',
  );

  static const bool _internalBuild = bool.fromEnvironment(
    'VOICEMEMORY_CLINICAL_SANDBOX_INTERNAL_BUILD',
  );

  /// Test-only override — never set in production code.
  @visibleForTesting
  static bool? debugOverride;

  /// True only when every compile-time and runtime safety check passes.
  static bool get isEnabled => debugOverride ?? _resolvedEnabled;

  static bool get _resolvedEnabled {
    if (!_compileTimeEnabled) return false;
    if (_devToken.trim().isEmpty) return false;

    if (kReleaseMode && !_internalBuild) {
      assert(
        false,
        'Clinical sandbox must not ship enabled in public distribution builds',
      );
      return false;
    }

    return true;
  }

  /// Call once during app bootstrap to catch misconfigured public builds early.
  static void assertSafeForPublicDistribution() {
    if (!_compileTimeEnabled) return;

    assert(
      _devToken.trim().isNotEmpty,
      'VOICEMEMORY_CLINICAL_SANDBOX_DEV_TOKEN is required when the clinical '
      'sandbox flag is enabled',
    );

    if (kReleaseMode && !_internalBuild) {
      assert(
        false,
        'Clinical sandbox must not ship enabled in public distribution builds',
      );
    }
  }
}