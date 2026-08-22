import 'package:archiveme_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/widgets/patterns/archive_evolution_timeline_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveEvolutionTimeline _timeline({
  int eventCount = 6,
  bool withNextCheck = false,
}) {
  final events = List.generate(
    eventCount,
    (i) => ArchiveEvolutionEvent(
      id: 'e$i',
      date: DateTime(2026, 5).add(Duration(days: i)),
      type: i == 0
          ? ArchiveEvolutionEventType.firstSeen
          : ArchiveEvolutionEventType.showedAgain,
      title: i == 0 ? 'First seen' : 'Showed up again',
      body: 'Moment $i',
    ),
  );
  return ArchiveEvolutionTimeline(
    patternTitle: 'Taking responsibility before asking for help',
    events: events.take(20).toList(),
    eventCount: eventCount,
    firstSeenDate: DateTime(2026, 5),
    lastSeenDate: DateTime(2026, 5, 6),
    nextCheck: withNextCheck ? 'Did you ask for help before saying yes?' : null,
  );
}

Future<void> _pump(
  WidgetTester tester,
  ArchiveEvolutionTimeline timeline, {
  VoidCallback? onOpenTimeline,
  void Function(String nextCheck)? onUseCheck,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ArchiveEvolutionTimelineCard(
            timeline: timeline,
            onOpenTimeline: onOpenTimeline,
            onUseCheck: onUseCheck,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders first 4 events and open CTA', (tester) async {
    await _pump(tester, _timeline());
    expect(find.text('Pattern timeline'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.archiveTimelineSubtitle), findsOneWidget);
    expect(find.text('First seen'), findsOneWidget);
    expect(find.text('Moment 0'), findsOneWidget);
    expect(find.text('Moment 3'), findsOneWidget);
    expect(find.text('Moment 4'), findsNothing);
    expect(find.text('Open timeline'), findsOneWidget);
  });

  testWidgets('Open timeline callback fires', (tester) async {
    var opened = false;
    await _pump(tester, _timeline(), onOpenTimeline: () => opened = true);
    await tester.tap(find.text('Open timeline'));
    await tester.pump();
    expect(opened, isTrue);
  });

  testWidgets('Use this check fires when nextCheck is set', (tester) async {
    String? used;
    await _pump(
      tester,
      _timeline(withNextCheck: true),
      onUseCheck: (q) => used = q,
    );
    expect(find.text('Use this check'), findsOneWidget);
    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(used, 'Did you ask for help before saying yes?');
  });
}