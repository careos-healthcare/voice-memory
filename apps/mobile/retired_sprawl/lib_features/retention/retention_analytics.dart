import 'package:archiveme_mobile/services/product_analytics.dart';
import 'dart:async';

/// Retention engine analytics.
class RetentionAnalytics {
  RetentionAnalytics._();

  static void instantBeliefViewed() {
    unawaited(ProductAnalytics.track('instant_belief_viewed'));
  }

  static void instantBeliefEvidenceOpened() {
    unawaited(ProductAnalytics.track('instant_belief_evidence_opened'));
  }

  static void discoveryBannerOpened() {
    unawaited(ProductAnalytics.track('discovery_banner_opened'));
  }

  static void weeklyStoryViewed() {
    unawaited(ProductAnalytics.track('weekly_story_viewed'));
  }

  static void weeklyStoryOpened() {
    unawaited(ProductAnalytics.track('weekly_story_opened'));
  }

  static void evidenceOpened({required String context}) {
    unawaited(ProductAnalytics.trackStrings('evidence_opened', {'context': context}));
  }

  static void evidenceRecordOpened({required String surface}) {
    unawaited(ProductAnalytics.trackStrings('evidence_record_opened', {
      'surface': surface,
    }));
  }

  static void progressIdentityViewed() {
    unawaited(ProductAnalytics.track('progress_identity_viewed'));
  }
}