import '../../services/product_analytics.dart';

/// Retention engine analytics.
class RetentionAnalytics {
  RetentionAnalytics._();

  static void instantBeliefViewed() {
    ProductAnalytics.track('instant_belief_viewed');
  }

  static void instantBeliefEvidenceOpened() {
    ProductAnalytics.track('instant_belief_evidence_opened');
  }

  static void discoveryBannerOpened() {
    ProductAnalytics.track('discovery_banner_opened');
  }

  static void weeklyStoryViewed() {
    ProductAnalytics.track('weekly_story_viewed');
  }

  static void weeklyStoryOpened() {
    ProductAnalytics.track('weekly_story_opened');
  }

  static void evidenceOpened({required String context}) {
    ProductAnalytics.trackStrings('evidence_opened', {'context': context});
  }

  static void evidenceRecordOpened({required String surface}) {
    ProductAnalytics.trackStrings('evidence_record_opened', {
      'surface': surface,
    });
  }

  static void progressIdentityViewed() {
    ProductAnalytics.track('progress_identity_viewed');
  }
}
