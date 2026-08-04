import '../../services/product_analytics.dart';

/// Discover Yourself analytics.
class DiscoverAnalytics {
  DiscoverAnalytics._();

  static void discoverOpened({required int reflectionCount}) {
    ProductAnalytics.track(
      'discover_opened',
      parameters: {'reflection_count': reflectionCount},
    );
  }

  static void beliefExpanded() {
    ProductAnalytics.track('belief_expanded');
  }

  static void themeExpanded({required String theme}) {
    ProductAnalytics.track('theme_expanded');
  }

  static void contradictionViewed() {
    ProductAnalytics.track('contradiction_viewed');
  }

  static void blindSpotViewed({required String id}) {
    ProductAnalytics.track('blind_spot_viewed');
  }

  static void chapterOpened({required String chapterId}) {
    ProductAnalytics.track('chapter_opened');
  }

  static void archiveQuestionAsked({required String prompt}) {
    ProductAnalytics.track('archive_question_asked');
  }
}
