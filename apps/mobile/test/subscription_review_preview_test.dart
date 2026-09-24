import 'package:archiveme_mobile/billing/longer_story_paywall.dart';
import 'package:archiveme_research/screens/subscription_review_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('founder lifetime is shown only when that offering exists', () {
    expect(founderLifetimeOfferingExists(['annual', 'monthly']), isFalse);
    expect(
      founderLifetimeOfferingExists([founderLifetimeOfferingId]),
      isTrue,
    );
    expect(founderLifetimeCap, 500);
  });

  testWidgets('review paywall leads with the pattern, quotes, and annual', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: SubscriptionReviewPreviewScreen()),
    );
    await tester.pump();

    expect(find.text(LongerStoryPaywall.headline), findsOneWidget);
    expect(find.text(LongerStoryPaywall.reviewPattern), findsOneWidget);
    expect(find.text(LongerStoryPaywall.reviewQuotes[0]), findsOneWidget);
    expect(find.text(LongerStoryPaywall.reviewQuotes[1]), findsOneWidget);
    expect(find.text(LongerStoryPaywall.freeKeeps), findsOneWidget);
    expect(find.text(LongerStoryPaywall.proKeeps), findsOneWidget);
    expect(find.text('£39.99/year'), findsOneWidget);
    expect(find.text('£4.99/month'), findsWidgets);
    expect(find.text(LongerStoryPaywall.restoreLabel), findsOneWidget);
    expect(find.text(LongerStoryPaywall.termsLabel), findsOneWidget);
    expect(find.text('Founder lifetime · first 500'), findsNothing);
    expect(find.text(LongerStoryPaywall.purchaseLabel), findsOneWidget);

    final annual = tester.getTopLeft(find.text(LongerStoryPaywall.annualTitle));
    final monthly = tester.getTopLeft(
      find.text(LongerStoryPaywall.monthlyTitle),
    );
    expect(annual.dy, lessThan(monthly.dy));
  });

  testWidgets('founder lifetime appears when the offering is supplied', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LongerStoryPaywall(
          patternTitle: 'A pattern',
          quotes: ['One quote.', 'Another quote.'],
          founderLifetimePrice: '£79',
        ),
      ),
    );
    expect(find.text('Founder lifetime · first 500'), findsOneWidget);
    expect(find.text('£79'), findsOneWidget);
  });

  testWidgets('no purchase control before first proof', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LongerStoryPaywall(
          patternTitle: 'A pattern',
          quotes: ['One quote.', 'Another quote.'],
          purchaseAllowed: false,
        ),
      ),
    );
    expect(find.text(LongerStoryPaywall.purchaseLabel), findsNothing);
    expect(find.text(LongerStoryPaywall.restoreLabel), findsOneWidget);
  });
}
