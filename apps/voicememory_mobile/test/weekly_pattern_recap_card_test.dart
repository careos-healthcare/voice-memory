import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/weekly_pattern_recap_model.dart';
import 'package:voicememory_mobile/widgets/patterns/weekly_recap_card.dart'
    as patterns;
import 'package:voicememory_mobile/widgets/record/weekly_pattern_recap_card.dart'
    as record;

WeeklyPatternRecap _recap({
  String? nextQuestion = 'What happens right before it starts?',
}) => WeeklyPatternRecap(
  id: 'wr_pm1_20260601_repeated',
  memoryId: 'pm1',
  createdAt: DateTime(2026, 6, 4),
  weekStart: DateTime(2026, 6, 1),
  weekEnd: DateTime(2026, 6, 7),
  type: WeeklyPatternRecapType.repeated,
  patternTitle: 'saying yes when you mean no',
  headline: 'This pattern kept showing up this week.',
  body: 'You checked it 4 times and caught it more than once.',
  usefulLine: 'It often starts around: before saying yes',
  nextQuestion: nextQuestion,
  checkInCount: 4,
  shouldShow: true,
);

void main() {
  testWidgets('record card shows "This week" with recap details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: record.WeeklyPatternRecapCard(recap: _recap()),
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(
      find.text('This pattern kept showing up this week.'),
      findsOneWidget,
    );
    expect(
      find.text('It often starts around: before saying yes'),
      findsOneWidget,
    );
    expect(find.text('What happens right before it starts?'), findsOneWidget);
    expect(find.text('Use this next week'), findsOneWidget);
  });

  testWidgets('record CTA creates tomorrow check-in from next question', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: record.WeeklyPatternRecapCard(
            recap: _recap(),
            onUseNext: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use this next week'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('patterns card shows weekly recap with "Use this check"', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: patterns.WeeklyPatternRecapCard(
              recap: _recap(),
              onUseNext: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Use this check'), findsOneWidget);

    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('patterns card hides CTA when there is no next question', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: patterns.WeeklyPatternRecapCard(
              recap: _recap(nextQuestion: null),
            ),
          ),
        ),
      ),
    );

    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Use this check'), findsNothing);
  });
}
