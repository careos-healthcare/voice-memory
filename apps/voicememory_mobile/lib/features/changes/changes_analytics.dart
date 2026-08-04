import '../../services/product_analytics.dart';

/// The only Changes-side analytics surface, expressed as a closed enum.
///
/// Callers cannot supply an event name, and no parameter carries content, so a
/// thread label, quote, entry id, or date cannot reach a provider from here.
enum ChangesAnalyticsEvent {
  changesOpened,
  changeThreadOpened,
  weeklyReviewOpened,
}

abstract final class ChangesAnalytics {
  ChangesAnalytics._();

  static Future<void> record(ChangesAnalyticsEvent event) =>
      ProductAnalytics.trackActivation(_id(event));

  /// Registered V1 ids. These are constants, never derived from user data.
  static String _id(ChangesAnalyticsEvent event) => switch (event) {
    ChangesAnalyticsEvent.changesOpened => 'changes_opened',
    ChangesAnalyticsEvent.changeThreadOpened => 'change_thread_opened',
    ChangesAnalyticsEvent.weeklyReviewOpened => 'weekly_review_opened',
  };
}
