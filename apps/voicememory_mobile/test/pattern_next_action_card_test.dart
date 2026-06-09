import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_next_action_model.dart';
import 'package:voicememory_mobile/widgets/record/pattern_next_action_card.dart';

PatternNextAction _action() => PatternNextAction(
      id: 'na_pm1_3_repeatCheck',
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      type: PatternNextActionType.repeatCheck,
      title: 'Check what happens before it starts',
      body: 'You have caught this pattern more than once. '
          'Tomorrow, look at the moment right before it shows up.',
      question: 'What happens right before it shows up?',
      ctaLabel: 'Use this check',
      sourceProgressType: 'stillRepeating',
      sourceStatus: 'active',
    );

void main() {
  testWidgets('shows "Next useful check" with title, body, and question',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternNextActionCard(action: _action()),
          ),
        ),
      ),
    );

    expect(find.text('Next useful check'), findsOneWidget);
    expect(find.text('Check what happens before it starts'), findsOneWidget);
    expect(find.textContaining('caught this pattern more than once'),
        findsOneWidget);
    expect(find.text('What happens right before it shows up?'), findsOneWidget);
  });

  testWidgets('CTA fires the onUse callback', (tester) async {
    var used = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PatternNextActionCard(
            action: _action(),
            onUse: () => used = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(used, isTrue);
  });
}
