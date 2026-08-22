import 'package:archiveme_mobile/services/product_analytics.dart';

/// Safe analytics for early saved-moments review — no user text.
abstract final class EarlySavedMomentsAnalytics {
  EarlySavedMomentsAnalytics._();

  static const viewedEvent = 'early_saved_moments_viewed';

  static Future<void> viewed({
    required int entryCount,
    required bool hasConfirmedRepeat,
  }) => ProductAnalytics.track(
    viewedEvent,
    parameters: {
      'entry_count': entryCount,
      'source': 'record',
      'has_confirmed_repeat': hasConfirmedRepeat,
    },
  );
}