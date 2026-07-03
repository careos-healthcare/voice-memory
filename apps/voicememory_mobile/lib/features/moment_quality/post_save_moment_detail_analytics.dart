import '../../services/product_analytics.dart';

/// Safe analytics for post-save moment detail — no user text.
abstract final class PostSaveMomentDetailAnalytics {
  PostSaveMomentDetailAnalytics._();

  static const promptTappedEvent = 'post_save_detail_prompt_tapped';
  static const savedEvent = 'post_save_detail_saved';
  static const failedEvent = 'post_save_detail_failed';

  static Future<void> promptTapped({
    required String detailType,
    required int entryCount,
  }) =>
      ProductAnalytics.track(
        promptTappedEvent,
        parameters: {
          'detail_type': detailType,
          'entry_count': entryCount,
          'source': 'record_post_save',
        },
      );

  static Future<void> saved({
    required String detailType,
    required int entryCount,
  }) =>
      ProductAnalytics.track(
        savedEvent,
        parameters: {
          'detail_type': detailType,
          'entry_count': entryCount,
          'source': 'record_post_save',
        },
      );

  static Future<void> failed({
    required String detailType,
    required int entryCount,
  }) =>
      ProductAnalytics.track(
        failedEvent,
        parameters: {
          'detail_type': detailType,
          'entry_count': entryCount,
          'source': 'record_post_save',
        },
      );
}
