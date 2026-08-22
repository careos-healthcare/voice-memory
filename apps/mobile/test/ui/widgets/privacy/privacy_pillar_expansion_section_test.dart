import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/ui/widgets/privacy/privacy_pillar_expansion_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(PrivacySecurityEngagementAnalytics.resetForTest);

  testWidgets('pillar expansion and explanation emit engagement events', (
    tester,
  ) async {
    final events = <String, Map<String, Object>>{};
    PrivacySecurityEngagementAnalytics.captureForTest = (event, props) {
      events[event] = props;
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: PrivacyPillarExpansionSection(
            cardId: PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId,
            title: PrivacySecurityControlCenterCopy.pillar3Heading,
            explanationTitle:
                PrivacySecurityControlCenterCopy.pillar3ExplanationTitle,
            explanationBody:
                PrivacySecurityControlCenterCopy.pillar3ExplanationBody,
            children: const [Text('child')],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(
      events[PrivacySecurityEngagementAnalytics.trustCardExpandedEvent],
      {
        'card_id': 'pillar_3_encryption',
        'expanded': true,
      },
    );

    await tester.tap(
      find.byKey(
        const Key(
          'privacy_pillar_why_${PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId}',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      events[PrivacySecurityEngagementAnalytics.trustExplanationViewedEvent],
      {'pillar_id': 'pillar_3_encryption'},
    );
    expect(
      find.byKey(
        const Key(
          'privacy_pillar_explanation_dialog_${PrivacySecurityEngagementAnalytics.pillar3EncryptionCardId}',
        ),
      ),
      findsOneWidget,
    );
  });
}
