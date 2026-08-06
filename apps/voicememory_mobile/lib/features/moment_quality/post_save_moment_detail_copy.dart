import 'post_save_moment_detail_model.dart';

/// Copy for post-save moment detail capture — no scores or pressure.
abstract final class PostSaveMomentDetailCopy {
  PostSaveMomentDetailCopy._();

  static const saveDetailCta = 'Save detail';
  static const cancelCta = 'Cancel';
  static const savedConfirmation = 'Detail saved.';
  static const saveFailedMessage =
      'That detail was not saved. Please try again.';

  static String promptTitle(PostSaveMomentDetailType type) => switch (type) {
    PostSaveMomentDetailType.situation => 'What was the situation?',
    PostSaveMomentDetailType.changed => 'What changed?',
    PostSaveMomentDetailType.stoodOut => 'What made this stand out?',
  };

  static String promptHelper(PostSaveMomentDetailType type) => switch (type) {
    PostSaveMomentDetailType.situation => 'One short detail is enough.',
    PostSaveMomentDetailType.changed =>
      'Keep it short. ArchiveMe will use this as evidence later.',
    PostSaveMomentDetailType.stoodOut =>
      'Add the detail that made this moment noticeable.',
  };

  static const detailFieldHint = 'Type your detail here…';
}
