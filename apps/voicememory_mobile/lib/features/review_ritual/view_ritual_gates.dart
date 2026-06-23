import 'view_ritual_copy.dart';
import 'view_ritual_models.dart';

/// Visibility gates for review ritual surfaces.
abstract final class ReviewRitualGates {
  ReviewRitualGates._();

  static bool showOnArchiveHome({
    required int realSavedMomentCount,
    required bool weeklyReviewAvailable,
    required bool sampleMode,
  }) =>
      !sampleMode &&
      (realSavedMomentCount >= 3 || weeklyReviewAvailable);
}
