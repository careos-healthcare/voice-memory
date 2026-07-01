import 'package:flutter/foundation.dart';

/// Gates ArchiveMe loop-map beta debug controls from profile/release builds.
///
/// Uses [kDebugMode] only — not [AppConfig.isDebugBuild], so `VM_DEBUG_TOOLS`
/// cannot surface scripted saves, CSV export, or force-return hooks in the field.
abstract class ArchiveBetaDebugGate {
  ArchiveBetaDebugGate._();

  /// Widget keys that must never render when [showLoopDebugControls] is false.
  static const debugControlKeys = <String>[
    'debug_enable_archive_loop_pro',
    'archive_loop_debug_unlock_pro_button',
    'archive_loop_debug_confirm_first_node',
    'debug_reset_archive_loop_onboarding',
    'debug_export_loop_map_validation',
    'debug_export_paid_intent_feedback',
    'debug_export_beta_evidence',
    'debug_clear_beta_activation_loop',
    'activation_dropoff_review_card',
    'debug_export_activation_funnel',
    'debug_clear_beta_evidence',
    'debug_copy_launch_readiness',
    'debug_force_return_hook_due',
    'debug_save_onboarding_scripted_moment',
  ];

  @visibleForTesting
  static bool? visibleOverride;

  static const _releaseSmokeFromEnvironment = bool.fromEnvironment(
    'ARCHIVEME_RELEASE_SMOKE',
    defaultValue: false,
  );

  /// True only in IDE debug builds — never profile, release, or dart-define tools.
  static bool get showLoopDebugControls {
    if (visibleOverride != null) return visibleOverride!;
    if (_releaseSmokeFromEnvironment || kReleaseMode || kProfileMode) {
      return false;
    }
    return kDebugMode;
  }

  @visibleForTesting
  static void resetForTest() {
    visibleOverride = null;
  }
}
