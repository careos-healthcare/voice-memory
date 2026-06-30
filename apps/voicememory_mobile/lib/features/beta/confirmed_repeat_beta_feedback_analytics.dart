import '../../services/activation_funnel_analytics.dart';
import 'confirmed_repeat_beta_feedback_models.dart';

/// Safe analytics for first confirmed-repeat beta feedback — metadata only.
abstract final class ConfirmedRepeatBetaFeedbackAnalytics {
  ConfirmedRepeatBetaFeedbackAnalytics._();

  static const String choiceEvent = 'confirmed_repeat_beta_feedback';
  static const String dismissedEvent = 'confirmed_repeat_beta_feedback_dismissed';
  static const String noteSavedEvent = 'confirmed_repeat_beta_feedback_note_saved';

  static void recordChoice({
    required ConfirmedRepeatBetaFeedbackChoice choice,
    required int entryCount,
    required String surface,
  }) {
    ActivationFunnelAnalytics.track(
      choiceEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'confirmed_repeat',
      reason: choice.analyticsReason,
    );
  }

  static void recordDismissed({
    required int entryCount,
    required String surface,
  }) {
    ActivationFunnelAnalytics.track(
      dismissedEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'confirmed_repeat',
    );
  }

  static void recordNoteSaved({
    required ConfirmedRepeatBetaFeedbackChoice choice,
    required int entryCount,
    required String surface,
    required bool hasNote,
  }) {
    ActivationFunnelAnalytics.track(
      noteSavedEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'confirmed_repeat',
      reason: choice.analyticsReason,
      method: hasNote ? 'has_note' : 'no_note',
    );
  }
}
