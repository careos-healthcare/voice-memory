import 'package:archiveme_mobile/services/product_analytics.dart';
import 'dart:async';

/// Discover Yourself analytics.
class DiscoverAnalytics {
  DiscoverAnalytics._();

  static void discoverOpened({required int reflectionCount}) {
    unawaited(ProductAnalytics.trackStrings('discover_opened', {
      'reflection_count': '$reflectionCount',
    }));
  }

  static void beliefExpanded() {
    unawaited(ProductAnalytics.track('belief_expanded'));
  }

  static void themeExpanded({required String theme}) {
    unawaited(ProductAnalytics.trackStrings('theme_expanded', {'theme': theme}));
  }

  static void contradictionViewed() {
    unawaited(ProductAnalytics.track('contradiction_viewed'));
  }

  static void blindSpotViewed({required String id}) {
    unawaited(ProductAnalytics.trackStrings('blind_spot_viewed', {'id': id}));
  }

  static void chapterOpened({required String chapterId}) {
    unawaited(ProductAnalytics.trackStrings('chapter_opened', {'chapter_id': chapterId}));
  }

  static void archiveQuestionAsked({required String prompt}) {
    unawaited(ProductAnalytics.trackStrings('archive_question_asked', {'prompt': prompt}));
  }
}