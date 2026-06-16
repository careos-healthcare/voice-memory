import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/archive_memory/archive_evolution_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/archive_evolution_timeline_screen.dart';

ArchiveEvolutionTimeline _timeline() => ArchiveEvolutionTimeline(
  patternTitle: 'Taking responsibility before asking for help',
  firstSeenDate: DateTime(2026, 5, 4),
  lastSeenDate: DateTime(2026, 5, 25),
  eventCount: 3,
  nextCheck: 'Did you ask for help before saying yes?',
  events: [
    ArchiveEvolutionEvent(
      id: 'e1',
      date: DateTime(2026, 5, 4),
      type: ArchiveEvolutionEventType.firstSeen,
      title: 'First seen',
      body: 'First moment saved',
    ),
    ArchiveEvolutionEvent(
      id: 'e2',
      date: DateTime(2026, 5, 10),
      type: ArchiveEvolutionEventType.showedAgain,
      title: 'Showed up again',
      body: 'It showed up again',
    ),
    ArchiveEvolutionEvent(
      id: 'e3',
      date: DateTime(2026, 5, 20),
      type: ArchiveEvolutionEventType.feltLighter,
      title: 'Felt lighter',
      body: 'It felt lighter after pausing',
    ),
  ],
);

void main() {
  testWidgets('renders full timeline and next check', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveEvolutionTimelineScreen(
          loader: () async => _timeline(),
          firstLoopClosed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pattern timeline'), findsOneWidget);
    expect(
      find.text('Taking responsibility before asking for help'),
      findsOneWidget,
    );
    expect(find.text('First seen'), findsOneWidget);
    expect(find.text('Felt lighter'), findsOneWidget);
    expect(
      find.text('Did you ask for help before saying yes?'),
      findsOneWidget,
    );
    expect(find.text('Use this check'), findsOneWidget);
  });

  testWidgets('Use this check fires callback', (tester) async {
    String? used;
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveEvolutionTimelineScreen(
          loader: () async => _timeline(),
          onUseCheck: (q) async => used = q,
          firstLoopClosed: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use this check'));
    await tester.pump();
    expect(used, 'Did you ask for help before saying yes?');
  });

  testWidgets('non-Pro after first loop shows preview and memory limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ArchiveEvolutionTimelineScreen(
          loader: () async => _timeline(),
          entitlementReader: FakeArchiveEntitlementReader(pro: false),
          firstLoopClosed: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(ConsumerUiCopy.patternMemoryGrowingTitle), findsOneWidget);
    expect(find.text('Use this check'), findsNothing);
  });
}
