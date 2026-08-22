import 'package:archiveme_mobile/features/onboarding/ui/trust_badge.dart';
import 'package:archiveme_mobile/features/settings/ui/trust_badge_copy.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TrustBadge', () {
    testWidgets('shows on-device and storage statements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TrustBadge()),
        ),
      );

      expect(find.byKey(TrustBadge.badgeKey), findsOneWidget);
      expect(find.byKey(TrustBadge.onDeviceKey), findsOneWidget);
      expect(find.byKey(TrustBadge.storageKey), findsOneWidget);
      expect(find.text(TrustBadgeCopy.onDeviceProcessing), findsOneWidget);
      expect(find.text(TrustBadgeCopy.storage), findsOneWidget);
      expect(find.text(TrustBadgeCopy.onDeviceDetail), findsOneWidget);
      expect(find.text(TrustBadgeCopy.storageDetail), findsOneWidget);
    });

    testWidgets('compact mode hides supporting detail lines', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TrustBadge(compact: true)),
        ),
      );

      expect(find.text(TrustBadgeCopy.onDeviceProcessing), findsOneWidget);
      expect(find.text(TrustBadgeCopy.storage), findsOneWidget);
      expect(find.text(TrustBadgeCopy.onDeviceDetail), findsNothing);
      expect(find.text(TrustBadgeCopy.storageDetail), findsNothing);
    });

    // Remote processing exists and is consent-gated, and storage protection is
    // a runtime flag with an "unavailable" state, so the badge must not claim
    // processing is exclusively on-device or that the archive is encrypted.
    test('states no unqualified locality or encryption claim', () {
      final all = [
        TrustBadgeCopy.onDeviceProcessing,
        TrustBadgeCopy.onDeviceDetail,
        TrustBadgeCopy.storage,
        TrustBadgeCopy.storageDetail,
      ].join(' ').toLowerCase();

      expect(all, isNot(contains('entirely')));
      expect(all, isNot(contains('encrypt')));
      expect(all, isNot(contains('sqlite')));
      expect(TrustBadgeCopy.onDeviceProcessing.toLowerCase(), contains('by default'));
      expect(
        TrustBadgeCopy.onDeviceDetail,
        contains(PrivacyCopyPolicy.nothingSentUnlessFeatureChosen),
      );
    });
  });
}
