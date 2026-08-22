import 'package:archiveme_mobile/features/pattern_memory/habit_proof_model.dart';
import 'package:archiveme_mobile/widgets/patterns/habit_proof_card.dart'
    as patterns;
import 'package:archiveme_mobile/widgets/record/habit_proof_card.dart'
    as record;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HabitProofMoment _proof({
  String? nextLine = 'What happens right before it shows up?',
}) => HabitProofMoment(
  id: 'hp_pm1_3_progressFound',
  memoryId: 'pm1',
  createdAt: DateTime(2026, 6, 4),
  type: HabitProofType.progressFound,
  headline: 'Now there is something to compare.',
  body:
      'You can see whether this pattern is repeating, '
      'getting lighter, getting heavier, or changing.',
  proofLine: 'This pattern is still showing up.',
  nextLine: nextLine,
  checkInCount: 3,
  shouldShow: true,
);

void main() {
  testWidgets('record card shows "Why this is useful" with proof details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: record.HabitProofCard(proof: _proof()),
          ),
        ),
      ),
    );

    expect(find.text('Why this is useful'), findsOneWidget);
    expect(find.text('Now there is something to compare.'), findsOneWidget);
    expect(find.text('This pattern is still showing up.'), findsOneWidget);
    expect(find.text('What happens right before it shows up?'), findsOneWidget);
    expect(find.text('Keep this going'), findsOneWidget);
  });

  testWidgets('record CTA fires onKeepGoing callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: record.HabitProofCard(
            proof: _proof(),
            onKeepGoing: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Keep this going'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('patterns card shows "Why keep checking?" and uses next line', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: patterns.HabitProofCard(
              proof: _proof(),
              onUseNext: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Why keep checking?'), findsOneWidget);
    expect(find.text('Use next check'), findsOneWidget);

    await tester.tap(find.text('Use next check'));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('patterns card hides CTA when there is no next line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: patterns.HabitProofCard(proof: _proof(nextLine: null)),
          ),
        ),
      ),
    );

    expect(find.text('Why keep checking?'), findsOneWidget);
    expect(find.text('Use next check'), findsNothing);
  });
}