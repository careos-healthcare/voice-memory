import '../../services/product_analytics.dart';
import 'living_archive_models.dart';

/// Living Archive v1 product analytics.
class LivingArchiveAnalytics {
  LivingArchiveAnalytics._();

  static Future<void> mostImportantOpened(MostImportantInsight insight) async {
    await ProductAnalytics.trackStrings('most_important_insight_opened', {
      'priority': insight.priority.name,
      'route': insight.openedRoute,
    });
  }

  static Future<void> archiveWasWrongOpened() async {
    await ProductAnalytics.track('archive_was_wrong_opened');
  }

  static Future<void> beliefUnderReviewOpened() async {
    await ProductAnalytics.track('belief_under_review_opened');
  }

  static Future<void> whatChangedTodayOpened() async {
    await ProductAnalytics.track('what_changed_today_opened');
  }

  static Future<void> discoveryStreakViewed(int days) async {
    await ProductAnalytics.trackStrings('discovery_streak_viewed', {
      'days': days.toString(),
    });
  }

  static Future<void> viewAllDiscoveriesTapped() async {
    await ProductAnalytics.track('living_archive_view_all_discoveries');
  }
}
