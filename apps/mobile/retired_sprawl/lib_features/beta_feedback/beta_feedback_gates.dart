import 'package:archiveme_mobile/features/beta_feedback/beta_feedback_models.dart';

/// Visibility gates for the archive-home beta feedback card.
abstract final class BetaFeedbackGates {
  BetaFeedbackGates._();

  static bool showCard({
    required int realEntryCount,
    required bool sampleMode,
    required BetaFeedbackState state,
  }) =>
      !sampleMode &&
      realEntryCount >= 3 &&
      !state.dismissed &&
      !state.hasResponse;
}