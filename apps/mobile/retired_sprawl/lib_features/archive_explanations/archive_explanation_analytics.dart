import 'package:archiveme_mobile/services/product_analytics.dart';
import 'dart:async';

/// Archive explanation / cross-reference analytics.
class ArchiveExplanationAnalytics {
  ArchiveExplanationAnalytics._();

  static void whyOpened({required String insightKind}) {
    unawaited(ProductAnalytics.trackStrings('archive_why_opened', {'kind': insightKind}));
  }

  static void deeperOpened({required String insightKind}) {
    unawaited(ProductAnalytics.trackStrings('archive_deeper_opened', {
      'kind': insightKind,
    }));
  }

  static void contradictionOpened() {
    unawaited(ProductAnalytics.track('archive_contradiction_opened'));
  }

  static void timelineOpened() {
    unawaited(ProductAnalytics.track('archive_timeline_opened'));
  }

  static void relatedThemeOpened({required String themeKey}) {
    unawaited(ProductAnalytics.trackStrings('archive_related_theme_opened', {
      'theme': themeKey,
    }));
  }

  static void surpriseViewed({required String refId}) {
    unawaited(ProductAnalytics.trackStrings('archive_surprise_viewed', {'ref': refId}));
  }

  static void challengeViewed({required String refId}) {
    unawaited(ProductAnalytics.trackStrings('archive_challenge_viewed', {'ref': refId}));
  }
}