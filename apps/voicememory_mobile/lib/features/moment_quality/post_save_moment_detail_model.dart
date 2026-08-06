import 'moment_quality_copy.dart';

/// Post-save detail types for the moment quality coach.
enum PostSaveMomentDetailType {
  situation,
  changed,
  stoodOut;

  String get analyticsValue => switch (this) {
    PostSaveMomentDetailType.situation => 'situation',
    PostSaveMomentDetailType.changed => 'changed',
    PostSaveMomentDetailType.stoodOut => 'stood_out',
  };

  static PostSaveMomentDetailType? forSuggestion(String label) {
    if (label == MomentQualityCopy.someDetailSuggestions[0]) {
      return PostSaveMomentDetailType.situation;
    }
    if (label == MomentQualityCopy.someDetailSuggestions[1]) {
      return PostSaveMomentDetailType.changed;
    }
    if (label == MomentQualityCopy.someDetailSuggestions[2]) {
      return PostSaveMomentDetailType.stoodOut;
    }
    return null;
  }

  static String linkedCaptureContextTag({
    required PostSaveMomentDetailType type,
    required String parentEntryId,
  }) => 'post_save_detail_${type.analyticsValue}_$parentEntryId';
}
