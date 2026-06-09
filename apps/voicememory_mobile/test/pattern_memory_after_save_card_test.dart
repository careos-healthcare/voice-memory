import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:voicememory_mobile/widgets/record/pattern_memory_after_save_card.dart';

PatternMemory _memory() => PatternMemory(
      id: 'pm1',
      patternTitle: 'Taking responsibility before asking for help',
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 4),
      checkInCount: 4,
      showedAgainCount: 2,
      lighterCount: 1,
      heavierCount: 1,
      nextBestQuestion: 'What happens right before it shows up?',
      status: PatternMemoryStatus.active,
    );

void main() {
  testWidgets('shows counts and next question', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternMemoryAfterSaveCard(memory: _memory()),
          ),
        ),
      ),
    );

    expect(find.text('This pattern is building a memory'), findsOneWidget);
    expect(find.text('Checked 4 times'), findsOneWidget);
    expect(find.text('Showed up again 2 times'), findsOneWidget);
    expect(find.text('Felt lighter 1 times'), findsOneWidget);
    expect(find.text('Felt heavier 1 times'), findsOneWidget);
    expect(find.text('What to check next'), findsOneWidget);
    expect(
      find.text('What happens right before it shows up?'),
      findsOneWidget,
    );
  });

  testWidgets('Use this next triggers callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternMemoryAfterSaveCard(
              memory: _memory(),
              onUseNext: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Use this next'), findsOneWidget);
    await tester.tap(find.text('Use this next'));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
