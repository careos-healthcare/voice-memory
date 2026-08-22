import 'package:archiveme_mobile/features/post_save/post_save_archive_hierarchy.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_model.dart';
import 'package:archiveme_mobile/features/record/daily_mirror_stage.dart';

/// Presentation-only gates for repeat-detected Record post-save.
abstract class PostSaveRepeatUiGates {
  PostSaveRepeatUiGates._();

  /// One calm repeat card instead of the full post-save stack.
  static bool suppressNoisyRepeatPostSaveCards({
    required bool suppressNoisyFirstSaveCards,
    required bool showFirstProofMoment,
    required PostSavePrimaryArchiveKind? postSaveArchiveKind,
    required DailyMirrorResult? mirror,
  }) {
    if (suppressNoisyFirstSaveCards || showFirstProofMoment) return false;
    if (postSaveArchiveKind != PostSavePrimaryArchiveKind.discovery) {
      return false;
    }
    final resolved = mirror;
    if (resolved == null) return false;
    return resolved.stage == DailyMirrorStage.possibleLoop &&
        resolved.hasGroundedEvidence;
  }
}