import 'confirmed_repeat_beta_feedback_models.dart';

/// Visibility gates for first confirmed-repeat beta feedback.
abstract final class ConfirmedRepeatBetaFeedbackGates {
  ConfirmedRepeatBetaFeedbackGates._();

  /// Show only once, after the user can see confirmed-repeat proof — never
  /// while recording is active.
  static bool shouldShow({
    required bool viewingConfirmedRepeat,
    required bool isRecording,
    required ConfirmedRepeatBetaFeedbackState state,
  }) =>
      viewingConfirmedRepeat && !isRecording && !state.completed;

  /// Hide the inline accuracy row while the one-time beta prompt is pending.
  static bool suppressInlineAccuracyFeedback({
    required ConfirmedRepeatBetaFeedbackState state,
  }) =>
      !state.completed;
}
