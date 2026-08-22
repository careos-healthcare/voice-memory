import 'package:archiveme_mobile/features/monthly_review/monthly_pattern_review_model.dart';
import 'package:archiveme_mobile/widgets/patterns/monthly_pattern_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MonthlyPatternReview _review({String? nextCheck = 'What happens before it?'}) =>
    MonthlyPatternReview(
      monthLabel: 'June',
      momentCount: 9,
      checkInCount: 4,
      keptRepeating: 'Taking on too much',
      gotLighter: 'It felt lighter after I paused',
      gotHeavier: 'It felt heavier when I carried it',
      helped: 'I asked for help',
      nextCheck: nextCheck,
      confidenceLabel: 'Based on 9 moments this month',
    );

Future<void> _pump(
  WidgetTester tester,
  MonthlyPatternReview review, {
  void Function(String)? onUseCheck,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MonthlyPatternReviewCard(
            review: review,
            onUseCheck: onUseCheck,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the title and all sections', (tester) async {
    await _pump(tester, _review());

    expect(find.text('This month'), findsOneWidget);
    expect(find.text('June'), findsOneWidget);
    expect(find.text('This kept repeating'), findsOneWidget);
    expect(find.text('This got lighter'), findsOneWidget);
    expect(find.text('This got heavier'), findsOneWidget);
    expect(find.text('This helped'), findsOneWidget);
    expect(find.text('One check for next month'), findsOneWidget);
  });

  testWidgets('use next month\u2019s check fires the callback', (tester) async {
    String? used;
    await _pump(tester, _review(), onUseCheck: (q) => used = q);

    expect(find.text('Use next month\u2019s check'), findsOneWidget);
    await tester.tap(find.text('Use next month\u2019s check'));
    await tester.pumpAndSettle();

    expect(used, 'What happens before it?');
  });

  testWidgets('hides the CTA when there is no next check', (tester) async {
    await _pump(tester, _review(nextCheck: null), onUseCheck: (_) {});

    expect(find.text('Use next month\u2019s check'), findsNothing);
    expect(find.text('One check for next month'), findsNothing);
  });

  testWidgets('omits empty sections', (tester) async {
    const review = MonthlyPatternReview(
      monthLabel: 'June',
      momentCount: 8,
      checkInCount: 0,
      keptRepeating: 'Taking on too much',
      confidenceLabel: 'Based on 8 moments this month',
    );
    await _pump(tester, review);

    expect(find.text('This kept repeating'), findsOneWidget);
    expect(find.text('This got lighter'), findsNothing);
    expect(find.text('This helped'), findsNothing);
  });
}