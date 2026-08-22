import 'package:archiveme_mobile/features/early_archive/early_archive_insight_feedback_models.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';

/// Safe analytics for early archive insight accuracy feedback.
abstract final class EarlyArchiveInsightFeedbackAnalytics {
  EarlyArchiveInsightFeedbackAnalytics._();

  static const String feedbackEvent = 'early_archive_insight_feedback';

  static void record({
    required EarlyArchiveInsightType insightType,
    required EarlyArchiveInsightFeedbackValue value,
    required int entryCount,
    required String surface,
  }) {
    ActivationFunnelAnalytics.track(
      feedbackEvent,
      entryCount: entryCount,
      source: surface,
      stage: insightType.analyticsStage,
      reason: value.analyticsReason,
    );
  }
}