import '../../services/product_analytics.dart';

/// Archive Explanation V2 — interpretation journey analytics.
class ArchiveExplanationV2Analytics {
  ArchiveExplanationV2Analytics._();

  static Future<void> interpretationOpened({
    required String insightId,
    required String kind,
  }) async {
    await ProductAnalytics.trackStrings('interpretation_opened', {
      'insight_id': insightId,
      'kind': kind,
    });
  }

  static Future<void> interpretationCompleted({
    required String insightId,
    required String kind,
  }) async {
    await ProductAnalytics.trackStrings('interpretation_completed', {
      'insight_id': insightId,
      'kind': kind,
    });
  }

  static Future<void> followupQuestionViewed({
    required String insightId,
    required String kind,
  }) async {
    await ProductAnalytics.trackStrings('followup_question_viewed', {
      'insight_id': insightId,
      'kind': kind,
    });
  }

  static Future<void> followupQuestionUsed({
    required String insightId,
    required String kind,
  }) async {
    await ProductAnalytics.trackStrings('followup_question_used', {
      'insight_id': insightId,
      'kind': kind,
    });
  }

  static Future<void> goDeeperOpened({
    required String insightId,
    required String kind,
  }) async {
    await ProductAnalytics.trackStrings('interpretation_go_deeper_opened', {
      'insight_id': insightId,
      'kind': kind,
    });
  }
}
