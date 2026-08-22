import 'package:archiveme_mobile/services/product_analytics.dart';

/// Early Archive Wins V1 analytics.
abstract class EarlyArchiveInsightAnalytics {
  EarlyArchiveInsightAnalytics._();

  static Future<void> shown({
    required String surface,
    required String kind,
    required String topicLabel,
  }) {
    return ProductAnalytics.track(
      'early_insight_shown',
      parameters: {'surface': surface, 'kind': kind, 'topic_label': topicLabel},
    );
  }

  static Future<void> opened({
    required String surface,
    required String kind,
    required String topicLabel,
  }) {
    return ProductAnalytics.track(
      'early_insight_opened',
      parameters: {'surface': surface, 'kind': kind, 'topic_label': topicLabel},
    );
  }
}