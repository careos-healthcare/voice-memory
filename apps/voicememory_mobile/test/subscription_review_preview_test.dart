import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/paywall/archive_loop_entitlements.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_research/screens/subscription_review_preview.dart';

void main() {
  testWidgets('subscription review preview at iPhone 15 Pro size', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SubscriptionReviewPreviewScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.paywallHeadline), findsOneWidget);
    expect(
      find.text(ArchiveLoopPaywallCopy.subscriptionAutoRenewingSummary),
      findsOneWidget,
    );
    for (final bullet in ConsumerUiCopy.paywallBullets) {
      expect(find.text(bullet), findsNothing);
    }
    expect(
      find.text(ArchiveLoopPaywallCopy.subscriptionMonthlyTitle),
      findsOneWidget,
    );
    expect(find.text('£4.99/month'), findsOneWidget);
    expect(
      find.text(ArchiveLoopPaywallCopy.subscriptionYearlyTitle),
      findsOneWidget,
    );
    expect(find.text('£39.99/year'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    expect(find.text(ArchiveLoopPaywallCopy.eulaLabel), findsOneWidget);
    expect(
      find.text(ArchiveLoopPaywallCopy.privacyPolicyLabel),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.paywallPrimaryCta), findsOneWidget);
  });
}
