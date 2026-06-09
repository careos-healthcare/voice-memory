import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/pattern_memory/pattern_progress_model.dart';
import 'package:voicememory_mobile/widgets/patterns/pattern_progress_card.dart';

PatternProgressMoment _progress({
  PatternProgressType type = PatternProgressType.gettingLighter,
  String? helpedLine = 'What helped: paused before answering',
}) =>
    PatternProgressMoment(
      id: 'pp_pm1_3',
      memoryId: 'pm1',
      createdAt: DateTime(2026, 6, 4),
      type: type,
      headline: 'This pattern may be getting lighter.',
      body: 'You have checked it 3 times. '
          'Lately, it has felt lighter more than heavier.',
      helpedLine: helpedLine,
      nextLine: 'Next, watch what helps before it gets heavy.',
      checkInCount: 3,
      shouldShow: true,
    );

void main() {
  testWidgets('renders Pattern progress with headline, body and next line',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PatternProgressCard(progress: _progress()),
          ),
        ),
      ),
    );

    expect(find.text('Pattern progress'), findsOneWidget);
    expect(find.text('This pattern may be getting lighter.'), findsOneWidget);
    expect(find.textContaining('checked it 3 times'), findsOneWidget);
    expect(find.text('What helped: paused before answering'), findsOneWidget);
    expect(
      find.text('Next, watch what helps before it gets heavy.'),
      findsOneWidget,
    );
    expect(find.text('Record next moment'), findsOneWidget);
  });
}
