import '../../services/product_analytics.dart';

/// Discover Yourself analytics.
class DiscoverAnalytics {
  DiscoverAnalytics._();

  static void discoverOpened({required int reflectionCount}) {
    ProductAnalytics.trackStrings('discover_opened', {
      'reflection_count': '$reflectionCount',
    });
  }

  static void beliefExpanded() {
    ProductAnalytics.track('belief_expanded');
  }

  static void themeExpanded({required String theme}) {
    ProductAnalytics.trackStrings('theme_expanded', {'theme': theme});
  }

  static void contradictionViewed() {
    ProductAnalytics.track('contradiction_viewed');
  }

  static void blindSpotViewed({required String id}) {
    ProductAnalytics.trackStrings('blind_spot_viewed', {'id': id});
  }

  static void chapterOpened({required String chapterId}) {
    ProductAnalytics.trackStrings('chapter_opened', {'chapter_id': chapterId});
  }

  static void archiveQuestionAsked({required String prompt}) {
    ProductAnalytics.trackStrings('archive_question_asked', {'prompt': prompt});
  }
}
