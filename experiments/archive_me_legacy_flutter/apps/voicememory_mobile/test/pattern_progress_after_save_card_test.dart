import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/widgets/record/pattern_progress_after_save_card.dart';

PatternProgressMoment _progress() => PatternProgressMoment(
  id: 'pp_pm1_4',
  memoryId: 'pm1',
  createdAt: DateTime(2026, 6, 4),
  type: PatternProgressType.stillRepeating,
  headline: 'This pattern is still showing up.',
  body:
      'You have caught it 4 times. '
      'The useful part is that you are noticing the moment.',
  beforeLine: 'It often starts around: before saying yes',
  nextLine: 'Next, watch what happens right before it starts.',
  checkInCount: 4,
  shouldShow: true,
);

void main() {
  testWidgets('renders What changed with headline, body and next line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternProgressAfterSaveCard(progress: _progress()),
          ),
        ),
      ),
    );

    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('This pattern is still showing up.'), findsOneWidget);
    expect(find.textContaining('caught it 4 times'), findsOneWidget);
    expect(
      find.text('It often starts around: before saying yes'),
      findsOneWidget,
    );
    expect(
      find.text('Next, watch what happens right before it starts.'),
      findsOneWidget,
    );
  });

  testWidgets('Use this next triggers callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternProgressAfterSaveCard(
              progress: _progress(),
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
