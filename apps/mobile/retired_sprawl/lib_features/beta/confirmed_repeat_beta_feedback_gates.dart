import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_models.dart';

/// Visibility gates for confirmed-repeat beta feedback.
abstract final class ConfirmedRepeatBetaFeedbackGates {
  ConfirmedRepeatBetaFeedbackGates._();

  static const minEntryCount = 3;

  /// Show only once, after confirmed-repeat proof — never while recording.
  static bool shouldShow({
    required bool viewingConfirmedRepeat,
    required bool isRecording,
    required int entryCount,
    required ConfirmedRepeatBetaFeedbackState state,
  }) =>
      viewingConfirmedRepeat &&
      !isRecording &&
      entryCount >= minEntryCount &&
      !state.completed;

  /// Hide the inline accuracy row while the one-time beta prompt is pending.
  static bool suppressInlineAccuracyFeedback({
    required ConfirmedRepeatBetaFeedbackState state,
  }) => !state.completed;
}