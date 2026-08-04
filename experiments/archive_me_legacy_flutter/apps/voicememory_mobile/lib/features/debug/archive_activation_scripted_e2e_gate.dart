import 'package:flutter/foundation.dart';

/// Gates activation scripted E2E helpers from release smoke and store builds.
abstract class ArchiveActivationScriptedE2EGate {
  ArchiveActivationScriptedE2EGate._();

  static const debugConfirmFirstNodeKey =
      'archive_loop_debug_confirm_first_node';

  @visibleForTesting
  static bool? enabledOverride;

  static const _activationScriptedFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_ACTIVATION_SCRIPTED_E2E',
    defaultValue: false,
  );

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  /// True when activation paywall device E2E is running in a debug build.
  static bool get isEnabled {
    if (enabledOverride != null) return enabledOverride!;
    if (_releaseSmokeFromEnvironment || kReleaseMode || kProfileMode) {
      return false;
    }
    return kDebugMode && _activationScriptedFromEnvironment;
  }

  /// Debug-only confirm shortcut for activation scripted E2E.
  static bool get showDebugConfirmFirstNodeButton => isEnabled;

  @visibleForTesting
  static void resetForTest() {
    enabledOverride = null;
  }
}
