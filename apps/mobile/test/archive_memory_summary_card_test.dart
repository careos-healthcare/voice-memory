import 'package:archiveme_mobile/features/archive_memory/archive_memory_summary_model.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_memory_summary_card.dart';
import 'package:archiveme_mobile/widgets/patterns/memory_quality_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveMemorySummary _summary({String? nextCheck = 'Did you ask for help?'}) =>
    ArchiveMemorySummary(
      id: 'm1',
      patternTitle: 'Taking responsibility before asking for help',
      primaryMemoryLine:
          'You often take responsibility before asking for help.',
      startsBeforeLine: 'It often starts before: saying yes.',
      helpedLine: 'It has felt lighter when: pausing before answering.',
      basedOnMomentCount: 8,
      basedOnWeekCount: 3,
      clarityLabel: 'Clear pattern',
      nextCheck: nextCheck,
    );

Future<void> _pump(
  WidgetTester tester,
  ArchiveMemorySummary summary, {
  VoidCallback? onOpenPatternMap,
  VoidCallback? onFindMoments,
  void Function(String)? onUseCheck,
  bool showFeedback = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArchiveMemorySummaryCard(
            summary: summary,
            showFeedback: showFeedback,
            onOpenPatternMap: onOpenPatternMap,
            onFindMoments: onFindMoments,
            onUseCheck: onUseCheck,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the title, clarity, and remembered lines', (
    tester,
  ) async {
    await _pump(tester, _summary());
    expect(find.text('What ArchiveMe remembers'), findsOneWidget);
    expect(find.text('Clear pattern'), findsOneWidget);
    expect(
      find.text('You often take responsibility before asking for help.'),
      findsOneWidget,
    );
    expect(find.text('It often starts before: saying yes.'), findsOneWidget);
    expect(
      find.textContaining('Based on 8 moments across 3 weeks.'),
      findsOneWidget,
    );
  });

  testWidgets('renders memory quality chip in clarity area', (tester) async {
    await _pump(tester, _summary());
    expect(find.byType(MemoryQualityChip), findsOneWidget);
    expect(find.text('Clear pattern'), findsOneWidget);
    expect(find.textContaining('confidence'), findsNothing);
  });

  testWidgets('Open pattern map callback fires', (tester) async {
    var opened = false;
    await _pump(tester, _summary(), onOpenPatternMap: () => opened = true);
    await tester.tap(find.text('Open pattern map'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('Find related moments callback fires', (tester) async {
    var found = false;
    await _pump(tester, _summary(), onFindMoments: () => found = true);
    await tester.tap(find.text('Find related moments'));
    await tester.pump();
    expect(found, isTrue);
  });

  testWidgets('Use this check callback fires with the next check', (
    tester,
  ) async {
    String? used;
    await _pump(tester, _summary(), onUseCheck: (q) => used = q);
    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(used, 'Did you ask for help?');
  });

  testWidgets('hides the next check CTA when there is none', (tester) async {
    await _pump(tester, _summary(nextCheck: null));
    expect(find.text('Use this check'), findsNothing);
    expect(find.text('Next check'), findsNothing);
  });

  testWidgets('shows feedback chips when showFeedback is true', (tester) async {
    await _pump(tester, _summary());
    expect(find.text('Was this useful?'), findsOneWidget);
    expect(find.text('Too generic'), findsOneWidget);
    expect(find.text('More specific'), findsOneWidget);
  });

  testWidgets('hides feedback chips when showFeedback is false', (
    tester,
  ) async {
    await _pump(tester, _summary(), showFeedback: false);
    expect(find.text('Was this useful?'), findsNothing);
  });
}