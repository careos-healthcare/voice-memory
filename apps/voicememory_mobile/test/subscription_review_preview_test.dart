import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/subscription_review_preview.dart';

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
    for (final bullet in ConsumerUiCopy.paywallBullets) {
      expect(find.text(bullet), findsOneWidget);
    }
    expect(find.text('Monthly Plan'), findsOneWidget);
    expect(find.text('£4.99/month'), findsOneWidget);
    expect(find.text('Yearly Plan'), findsOneWidget);
    expect(find.text('£39.99/year'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.paywallPrimaryCta), findsOneWidget);
  });
}
