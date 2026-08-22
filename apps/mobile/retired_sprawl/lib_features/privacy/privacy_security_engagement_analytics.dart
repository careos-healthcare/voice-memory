import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

/// On-device privacy & security control center engagement — metadata only.
///
/// Events are written to [AppLogger] and never include journal text, caregiver
/// names, or other PII. Optional [captureForTest] supports widget tests.
abstract final class PrivacySecurityEngagementAnalytics {
  PrivacySecurityEngagementAnalytics._();

  static const trustCardExpandedEvent = 'trust_card_expanded';
  static const trustExplanationViewedEvent = 'trust_explanation_viewed';
  static const biometricEnforcementToggledEvent = 'biometric_enforcement_toggled';
  static const caregiverTokenRevokedEvent = 'caregiver_token_revoked';
  static const caregiverAuditLogExpandedEvent = 'caregiver_audit_log_expanded';

  static const pillar3EncryptionCardId = 'pillar_3_encryption';
  static const pillar4CaregiverCardId = 'pillar_4_caregiver';

  @visibleForTesting
  static void Function(String event, Map<String, Object> properties)?
      captureForTest;

  static void trustCardExpanded({
    required String cardId,
    required bool expanded,
  }) =>
      _track(trustCardExpandedEvent, {
        'card_id': cardId,
        'expanded': expanded,
      });

  static void trustExplanationViewed({required String pillarId}) =>
      _track(trustExplanationViewedEvent, {'pillar_id': pillarId});

  static void biometricEnforcementToggled({required bool enabled}) =>
      _track(biometricEnforcementToggledEvent, {'enabled': enabled});

  static void caregiverTokenRevoked({required String tokenId}) =>
      _track(caregiverTokenRevokedEvent, {'token_id': tokenId});

  static void caregiverAuditLogExpanded({required bool expanded}) =>
      _track(caregiverAuditLogExpandedEvent, {'expanded': expanded});

  static void _track(String event, Map<String, Object> properties) {
    captureForTest?.call(event, properties);
    AnalyticsServices.instance.logEvent(event, properties);
    if (kDebugMode) {
      AppLogger.debug('PRIVACY_ENGAGEMENT event=$event $properties');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    captureForTest = null;
    AnalyticsServices.resetForTest();
  }
}
