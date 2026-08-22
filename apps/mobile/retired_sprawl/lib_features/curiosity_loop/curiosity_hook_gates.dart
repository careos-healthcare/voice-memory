import 'package:archiveme_mobile/core/config/v1_retention_policy.dart';
import 'package:archiveme_mobile/features/curiosity_loop/models/curiosity_hook.dart';

/// Visibility gates for curiosity loop surfaces.
abstract final class CuriosityHookGates {
  CuriosityHookGates._();

  static bool shouldShowPostSaveCard({
    required bool isPostSaveDone,
    required CuriosityHook? hook,
    required bool isDegradedPostSave,
  }) =>
      V1RetentionPolicy.showCuriosityPostSaveHooks &&
      isPostSaveDone &&
      hook != null &&
      !hook.isConsumed &&
      !isDegradedPostSave;
}