import 'post_save_return_handoff_model.dart';

/// Visibility gates for the post-save return handoff on Record.
abstract final class PostSaveReturnHandoffGates {
  PostSaveReturnHandoffGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    PostSaveReturnHandoff? handoff,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount >= 1 &&
      entryCount <= 2 &&
      handoff != null;
}
