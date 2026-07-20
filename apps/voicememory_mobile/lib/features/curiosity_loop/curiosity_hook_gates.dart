import 'models/curiosity_hook.dart';

/// Visibility gates for curiosity loop surfaces.
abstract final class CuriosityHookGates {
  CuriosityHookGates._();

  static bool shouldShowPostSaveCard({
    required bool isPostSaveDone,
    required CuriosityHook? hook,
    required bool isDegradedPostSave,
  }) =>
      isPostSaveDone &&
      hook != null &&
      !hook.isConsumed &&
      !isDegradedPostSave;
}
