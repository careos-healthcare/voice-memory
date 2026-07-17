import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:voicememory_mobile/widgets/billing/paywall_subscription_details_section.dart';

void main() {
  group('PaywallSubscriptionDetailsSection', () {
    testWidgets('shows Terms and Privacy links', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaywallSubscriptionDetailsSection(
              plansAvailable: false,
            ),
          ),
        ),
      );

      expect(find.text(ProPackagingCopy.title), findsOneWidget);
      expect(
        find.textContaining(ArchiveLoopPaywallCopy.subscriptionMonthlyTitle),
        findsOneWidget,
      );
      expect(
        find.textContaining(ArchiveLoopPaywallCopy.subscriptionYearlyTitle),
        findsOneWidget,
      );
      expect(
        find.text(ArchiveLoopPaywallCopy.subscriptionPlansUnavailable),
        findsOneWidget,
      );
      expect(find.text(ArchiveLoopPaywallCopy.eulaLabel), findsOneWidget);
      expect(find.text(ArchiveLoopPaywallCopy.privacyPolicyLabel), findsOneWidget);
      expect(find.byKey(const Key('paywall_terms_of_use_link')), findsOneWidget);
      expect(find.byKey(const Key('paywall_privacy_policy_link')), findsOneWidget);
    });

    testWidgets('shows prices when plans are available', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaywallSubscriptionDetailsSection(
              monthlyPrice: r'$4.99',
              yearlyPrice: r'$39.99',
              plansAvailable: true,
            ),
          ),
        ),
      );

      expect(find.textContaining(r'$4.99'), findsOneWidget);
      expect(find.textContaining(r'$39.99'), findsOneWidget);
      expect(
        find.text(ArchiveLoopPaywallCopy.subscriptionPlansUnavailable),
        findsNothing,
      );
    });

    test('legal URLs match App Store submission requirements', () {
      expect(
        ArchiveLoopPaywallCopy.eulaUrl,
        'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
      );
      expect(
        ArchiveLoopPaywallCopy.privacyPolicyUrl,
        AppConfig.privacyUrl,
      );
    });
  });
}
