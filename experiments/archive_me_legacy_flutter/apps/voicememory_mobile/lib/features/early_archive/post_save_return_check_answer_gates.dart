import 'post_save_return_check_answer_model.dart';

/// Visibility gates for the post-save return check answer on Record post-save.
abstract final class PostSaveReturnCheckAnswerGates {
  PostSaveReturnCheckAnswerGates._();

  static bool shouldShow({
    required bool isPostSaveDone,
    required int entryCount,
    required bool isDegradedPostSave,
    required bool showFirstProofMoment,
    PostSaveReturnCheckAnswer? answer,
  }) =>
      isPostSaveDone &&
      !isDegradedPostSave &&
      entryCount >= 4 &&
      !showFirstProofMoment &&
      answer != null;
}
