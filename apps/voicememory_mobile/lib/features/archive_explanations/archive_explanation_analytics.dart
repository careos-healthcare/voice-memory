import '../../../services/product_analytics.dart';

/// Archive explanation / cross-reference analytics.
class ArchiveExplanationAnalytics {
  ArchiveExplanationAnalytics._();

  static void whyOpened({required String insightKind}) {
    ProductAnalytics.trackStrings('archive_why_opened', {'kind': insightKind});
  }

  static void deeperOpened({required String insightKind}) {
    ProductAnalytics.trackStrings('archive_deeper_opened', {'kind': insightKind});
  }

  static void contradictionOpened() {
    ProductAnalytics.track('archive_contradiction_opened');
  }

  static void timelineOpened() {
    ProductAnalytics.track('archive_timeline_opened');
  }

  static void relatedThemeOpened({required String themeKey}) {
    ProductAnalytics.trackStrings('archive_related_theme_opened', {
      'theme': themeKey,
    });
  }

  static void surpriseViewed({required String refId}) {
    ProductAnalytics.trackStrings('archive_surprise_viewed', {'ref': refId});
  }

  static void challengeViewed({required String refId}) {
    ProductAnalytics.trackStrings('archive_challenge_viewed', {'ref': refId});
  }
}
