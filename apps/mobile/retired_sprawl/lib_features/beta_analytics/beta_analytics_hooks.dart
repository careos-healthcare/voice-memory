import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_event_registry.dart';
import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_tracker.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';

/// UI and service hooks for beta analytics events.
abstract final class BetaAnalyticsHooks {
  BetaAnalyticsHooks._();

  static Future<void> onboardingViewed() => BetaAnalyticsTracker.trackOnce(
    'onboarding_viewed',
    parameters: const {'surface': 'onboarding'},
  );

  static Future<void> captureIntentSelected({required bool voice}) =>
      BetaAnalyticsTracker.track(
        'capture_intent_selected',
        parameters: {'intent': voice ? 'voice' : 'typed'},
      );

  static Future<void> archiveFirstViewed() => BetaAnalyticsTracker.trackOnce(
    'archive_first_viewed',
    parameters: const {'surface': 'archive'},
  );

  static Future<void> possiblePatternViewed({required String surface}) =>
      BetaAnalyticsTracker.track(
        'possible_pattern_viewed',
        parameters: {'surface': surface},
      );

  static Future<void> evidenceOpened({required String surface}) =>
      BetaAnalyticsTracker.track(
        'evidence_opened',
        parameters: {'surface': surface},
      );

  static Future<void> patternReviewed({required String reviewOutcome}) =>
      BetaAnalyticsTracker.track(
        'pattern_reviewed',
        parameters: {'review_outcome': reviewOutcome},
      );

  static Future<void> localSaveResult({
    required bool success,
    required String captureKind,
    required Duration latency,
  }) => BetaAnalyticsTracker.track(
    'local_save_result',
    parameters: {
      'result': success ? 'success' : 'failure',
      'capture_kind': captureKind,
      'latency_bucket': BetaAnalyticsLatencyBuckets.bucketFor(latency),
    },
  );

  static Future<void> remoteProcessingResult({
    required bool success,
    required bool skipped,
    required String kind,
    required Duration latency,
  }) => BetaAnalyticsTracker.track(
    'remote_processing_result',
    parameters: {
      'result': skipped
          ? 'skipped'
          : success
          ? 'success'
          : 'failure',
      'kind': kind,
      'latency_bucket': BetaAnalyticsLatencyBuckets.bucketFor(latency),
    },
  );

  static Future<void> exportResult({required bool success}) =>
      BetaAnalyticsTracker.track(
        'export_result',
        parameters: {'result': success ? 'success' : 'failure'},
      );

  static Future<void> deletionResult({
    required bool success,
    required String scope,
  }) => BetaAnalyticsTracker.track(
    'deletion_result',
    parameters: {
      'result': success ? 'success' : 'failure',
      'scope': scope,
    },
  );

  static Future<void> appRecoveryResult({
    required String result,
    required String reasonBucket,
  }) => BetaAnalyticsTracker.track(
    'app_recovery_result',
    parameters: {
      'result': result,
      'reason_bucket': reasonBucket,
    },
  );

  /// Emits eligibility only when policy confirms threshold.
  static Future<void> maybePossiblePatternEligible({
    required int admittedMomentCount,
  }) async {
    if (admittedMomentCount <
        EvidenceEligibilityPolicy.possiblePatternMinimum) {
      return;
    }
    await BetaAnalyticsTracker.trackOnce(
      'possible_pattern_eligible',
      parameters: {
        'policy_version': EvidenceEligibilityPolicy.policyVersion,
      },
    );
  }
}
