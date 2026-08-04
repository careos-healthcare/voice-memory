import 'product_analytics.dart';
import 'analytics/analytics_catalog.dart';

abstract final class EvidenceReceiptAnalytics {
  EvidenceReceiptAnalytics._();

  static Future<void> postSaveObservationShown({
    required int evidenceCount,
    required String confidenceBand,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.postSaveObservationShown,
    parameters: {
      'conclusion_kind': 'observation',
      'evidence_count': _countBand(evidenceCount),
      'confidence_band': _confidenceBand(confidenceBand),
      'ui_origin': 'record_post_save',
    },
  );

  static Future<void> postSaveNoConclusion() =>
      ProductAnalytics.track(V1AnalyticsEvent.postSaveNoConclusion);

  static Future<void> auditableConclusionShown({
    required String kind,
    required int evidenceCount,
    required String confidenceBand,
    required String origin,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.auditableConclusionShown,
    parameters: {
      'conclusion_kind': kind,
      'evidence_count': _countBand(evidenceCount),
      'confidence_band': _confidenceBand(confidenceBand),
      'ui_origin': origin,
    },
  );

  static Future<void> receiptOpened({
    required int evidenceCount,
    required String origin,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.evidenceReceiptOpened,
    parameters: {
      'evidence_count': _countBand(evidenceCount),
      'ui_origin': origin,
    },
  );

  static Future<void> sourceMomentOpened({
    required bool hasPlayableAudio,
    required String origin,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.exactSourceOpened,
    parameters: {
      'source_type': hasPlayableAudio ? 'voice' : 'text',
      'ui_origin': origin,
    },
  );

  static Future<void> interpretationFeedbackSubmitted({
    required String kind,
    required int evidenceCount,
    required String confidenceBand,
    required String sourceType,
    required String feedback,
    required int entryCount,
    required String origin,
    required bool corrected,
  }) => ProductAnalytics.track(
    corrected
        ? V1AnalyticsEvent.interpretationCorrected
        : V1AnalyticsEvent.interpretationFeedbackSubmitted,
    parameters: {
      'conclusion_kind': kind,
      'evidence_count': _countBand(evidenceCount),
      'confidence_band': _confidenceBand(confidenceBand),
      'source_type': sourceType,
      'feedback': _feedback(feedback),
      'entry_count_band': _countBand(entryCount),
      'ui_origin': origin,
    },
  );

  static Future<void> conclusionSuppressed({
    required String kind,
    required String feedback,
    required String origin,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.conclusionSuppressed,
    parameters: {
      'conclusion_kind': kind,
      'feedback': _feedback(feedback),
      'ui_origin': origin,
    },
  );

  static Future<void> earlyComparisonShown({
    required int evidenceCount,
    required String confidenceBand,
    required String origin,
  }) => ProductAnalytics.track(
    V1AnalyticsEvent.earlyComparisonShown,
    parameters: {
      'conclusion_kind': 'change',
      'evidence_count': _countBand(evidenceCount),
      'confidence_band': _confidenceBand(confidenceBand),
      'entry_count_band': 'two',
      'ui_origin': origin,
    },
  );

  static Future<void> reliableChangeDisplayed({required int evidenceCount}) =>
      ProductAnalytics.track(
        V1AnalyticsEvent.reliableChangeDisplayed,
        parameters: {'evidence_count_band': _countBand(evidenceCount)},
      );

  static Future<void> archiveSearchUsed() =>
      ProductAnalytics.track(V1AnalyticsEvent.archiveSearchUsed);

  static Future<void> changesViewed({required bool hasReliableChange}) =>
      ProductAnalytics.track(
        V1AnalyticsEvent.changesViewed,
        parameters: {
          'reliable_change_available': hasReliableChange ? 'yes' : 'no',
        },
      );

  static Future<void> lowEvidenceSuppressed({required String origin}) =>
      ProductAnalytics.track(
        V1AnalyticsEvent.insightNotDisplayedLowEvidence,
        parameters: {'origin': origin},
      );

  static String _countBand(int value) => switch (value) {
    <= 0 => 'none',
    1 => 'one',
    2 => 'two',
    _ => 'three_plus',
  };

  static String _confidenceBand(String value) => switch (value) {
    'earlyObservation' || 'early_observation' => 'early_observation',
    'someSupportingEvidence' ||
    'some_supporting_evidence' => 'some_supporting_evidence',
    'repeatedAcrossMoments' ||
    'repeated_across_moments' => 'repeated_across_moments',
    'stronglySupported' || 'strongly_supported' => 'strongly_supported',
    _ => 'unknown',
  };

  static String _feedback(String value) => switch (value) {
    'notQuite' || 'not_quite' => 'not_quite',
    'tooEarly' || 'too_early' => 'too_early',
    'saveAsWatchTheme' || 'save_as_watch_theme' => 'save_as_watch_theme',
    'wrongAngle' || 'wrong_angle' => 'wrong_angle',
    'tooGeneric' || 'too_generic' => 'too_generic',
    'fits' || 'accurate' || 'hide' => value,
    _ => 'unknown',
  };
}
