import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.pumpAndSettle();

    expect(find.text('ArchiveMe'), findsOneWidget);
    expect(find.text('Unlimited Voice Memories'), findsOneWidget);
    expect(find.text('AI Archive Insights'), findsOneWidget);
    expect(find.text('Search Across Memories'), findsOneWidget);
    expect(find.text('Secure Cloud Sync'), findsOneWidget);
    expect(find.text('Lifetime Archive Access'), findsOneWidget);
    expect(find.text('Monthly Plan'), findsOneWidget);
    expect(find.text('£4.99/month'), findsOneWidget);
    expect(find.text('Yearly Plan'), findsOneWidget);
    expect(find.text('£39.99/year'), findsOneWidget);
    expect(find.text('Save 33%'), findsOneWidget);
    expect(find.text('Start Free Trial'), findsOneWidget);
  });
}
