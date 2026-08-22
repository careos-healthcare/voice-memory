import 'package:archiveme_mobile/features/beta/core_value_feedback_model.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Safe metadata analytics for core value beta feedback — no journal text.
abstract final class CoreValueFeedbackAnalytics {
  CoreValueFeedbackAnalytics._();

  static const seenEvent = 'core_value_feedback_seen';
  static const answeredEvent = 'core_value_feedback_answered';
  static const dismissedEvent = 'core_value_feedback_dismissed';

  static void seen({
    required int entryCount,
    required CoreValueFeedbackSource source,
    required bool hasConfirmedRepeat,
    required bool hasFirstProof,
  }) {
    ActivationFunnelAnalytics.track(
      seenEvent,
      entryCount: entryCount,
      source: source.analyticsValue,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasFirstProof: hasFirstProof,
      oncePerSession: true,
    );
  }

  static void answered({
    required CoreValueFeedbackAnswer answer,
    required int entryCount,
    required CoreValueFeedbackSource source,
    required bool hasConfirmedRepeat,
    required bool hasFirstProof,
  }) {
    ActivationFunnelAnalytics.track(
      answeredEvent,
      answer: answer.analyticsValue,
      entryCount: entryCount,
      source: source.analyticsValue,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasFirstProof: hasFirstProof,
    );
  }

  static void dismissed({
    required int entryCount,
    required CoreValueFeedbackSource source,
    required bool hasConfirmedRepeat,
    required bool hasFirstProof,
  }) {
    ActivationFunnelAnalytics.track(
      dismissedEvent,
      entryCount: entryCount,
      source: source.analyticsValue,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasFirstProof: hasFirstProof,
    );
  }
}