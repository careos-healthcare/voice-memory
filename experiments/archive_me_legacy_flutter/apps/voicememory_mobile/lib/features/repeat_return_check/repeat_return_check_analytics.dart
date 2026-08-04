import '../../services/activation_funnel_analytics.dart';
import 'repeat_return_check_models.dart';

/// Metadata-only analytics for repeat intensity checks — never journal text.
abstract final class RepeatReturnCheckAnalytics {
  RepeatReturnCheckAnalytics._();

  static const String choiceEvent = 'repeat_return_check';
  static const String dismissedEvent = 'repeat_return_check_dismissed';
  static const String changeProofSeenEvent = 'repeat_return_check_proof_seen';

  static void recordChangeProofSeen({
    required RepeatReturnCheckChoice latestChoice,
    required int entryCount,
    required String surface,
  }) {
    ActivationFunnelAnalytics.track(
      changeProofSeenEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'repeat_return',
      reason: latestChoice.analyticsReason,
    );
  }

  static void recordChoice({
    required RepeatReturnCheckChoice choice,
    required int entryCount,
    required String surface,
  }) {
    ActivationFunnelAnalytics.track(
      choiceEvent,
      entryCount: entryCount,
      source: surface,
      stage: 'repeat_return',
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
      stage: 'repeat_return',
    );
  }
}
