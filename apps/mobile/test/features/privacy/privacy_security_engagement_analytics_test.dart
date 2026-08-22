import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(PrivacySecurityEngagementAnalytics.resetForTest);

  test('trustCardExpanded records card_id and expanded flag', () {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    PrivacySecurityEngagementAnalytics.trustCardExpanded(
      cardId: PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
      expanded: true,
    );

    expect(events.keys, contains(PrivacySecurityEngagementAnalytics.trustCardExpandedEvent));
    expect(
      events[PrivacySecurityEngagementAnalytics.trustCardExpandedEvent],
      {
        'card_id': 'pillar_3_encryption',
        'expanded': true,
      },
    );
  });

  test('trustExplanationViewed records pillar_id only', () {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    PrivacySecurityEngagementAnalytics.trustExplanationViewed(
      pillarId: PrivacySecurityEngagementAnalytics.pillar4CaregiverCardId,
    );

    expect(
      events[PrivacySecurityEngagementAnalytics.trustExplanationViewedEvent],
      {'pillar_id': 'pillar_4_caregiver'},
    );
  });

  test('biometricEnforcementToggled records enabled state', () {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    PrivacySecurityEngagementAnalytics.biometricEnforcementToggled(enabled: false);

    expect(
      events[PrivacySecurityEngagementAnalytics.biometricEnforcementToggledEvent],
      {'enabled': false},
    );
  });

  test('caregiverTokenRevoked records opaque token_id', () {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    PrivacySecurityEngagementAnalytics.caregiverTokenRevoked(
      tokenId: 'tok_abc123',
    );

    expect(
      events[PrivacySecurityEngagementAnalytics.caregiverTokenRevokedEvent],
      {'token_id': 'tok_abc123'},
    );
  });

  test('caregiverAuditLogExpanded records expanded state', () {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    PrivacySecurityEngagementAnalytics.caregiverAuditLogExpanded(expanded: true);

    expect(
      events[PrivacySecurityEngagementAnalytics.caregiverAuditLogExpandedEvent],
      {'expanded': true},
    );
  });
}
