import 'package:archiveme_mobile/features/pattern_memory/pattern_memory_model.dart';
import 'package:archiveme_mobile/widgets/patterns/pattern_memory_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

PatternMemory _memory({
  required PatternMemoryStatus status,
  List<String> before = const [],
  List<String> helped = const [],
  List<String> harder = const [],
  String? lastResult,
}) => PatternMemory(
  id: 'pm1',
  patternTitle: 'Taking responsibility before asking for help',
  createdAt: DateTime(2026, 6),
  updatedAt: DateTime(2026, 6, 4),
  checkInCount: 4,
  showedAgainCount: 2,
  lighterCount: 1,
  heavierCount: 1,
  lastResult: lastResult,
  commonBeforeMoments: before,
  helpedMoments: helped,
  harderMoments: harder,
  nextBestQuestion: 'What happens right before it shows up?',
  status: status,
);

Future<void> _pump(WidgetTester tester, PatternMemory memory) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: PatternMemoryCard(memory: memory)),
      ),
    ),
  );
}

void main() {
  testWidgets('active status shows correct copy, count and next question', (
    tester,
  ) async {
    await _pump(
      tester,
      _memory(
        status: PatternMemoryStatus.active,
        before: const ['when someone expected something', 'before saying yes'],
        helped: const ['paused before answering'],
        lastResult: PatternMemoryResultHint.same,
      ),
    );

    expect(find.text('This pattern keeps showing up.'), findsOneWidget);
    expect(find.textContaining('Checked 4 times'), findsOneWidget);
    expect(find.text('Before it shows up'), findsOneWidget);
    expect(find.text('· when someone expected something'), findsOneWidget);
    expect(find.text('What helped'), findsOneWidget);
    expect(find.text('Record next check-in'), findsOneWidget);
  });

  testWidgets('forming status copy', (tester) async {
    await _pump(tester, _memory(status: PatternMemoryStatus.forming));
    expect(
      find.text('ArchiveMe is starting to remember this pattern.'),
      findsOneWidget,
    );
  });

  testWidgets('easing status copy', (tester) async {
    await _pump(tester, _memory(status: PatternMemoryStatus.easing));
    expect(find.text('This pattern may be getting lighter.'), findsOneWidget);
  });

  testWidgets('needsAttention status shows harder moments', (tester) async {
    await _pump(
      tester,
      _memory(
        status: PatternMemoryStatus.needsAttention,
        harder: const ['carried it alone'],
      ),
    );
    expect(find.text('This pattern may need more attention.'), findsOneWidget);
    expect(find.text('What made it heavier'), findsOneWidget);
    expect(find.text('· carried it alone'), findsOneWidget);
  });

  testWidgets('changing status copy', (tester) async {
    await _pump(tester, _memory(status: PatternMemoryStatus.changing));
    expect(find.text('This pattern is changing.'), findsOneWidget);
  });
}