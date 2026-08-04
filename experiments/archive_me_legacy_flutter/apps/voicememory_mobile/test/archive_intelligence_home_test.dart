import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_beliefs/archive_belief_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_intelligence_home.dart';
import 'package:voicememory_mobile/features/archive_home/archive_intelligence_presentation.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

final _transcripts = [
  'I agreed to the extra meeting before checking whether I had capacity.',
  'I paused before answering and checked what was already on my calendar.',
  'I noticed pressure to say yes even though the week was already full.',
  'I asked for time before committing to another deadline at work.',
  'I declined the request after checking the work already accepted.',
];

List<JournalEntry> _entries() => [
  for (var i = 0; i < _transcripts.length; i++)
    JournalEntry(
      id: 'entry-$i',
      createdAt: DateTime(2026, 7, 20 + i),
      transcript: _transcripts[i],
      durationSeconds: 20,
      localAudioPath: '/vault/entry-$i.enc',
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 2,
        recurringThemes: ['capacity'],
        exactLanguagePattern: '',
        concreteObservation: 'Capacity pressure appeared.',
        repeatedSignal: '',
      ),
    ),
];

ArchiveBeliefsSnapshot _beliefs({bool lowEvidence = false}) {
  final quotes = lowEvidence
      ? List.filled(5, _transcripts.first)
      : _transcripts;
  final belief = ArchiveBeliefCardModel(
    id: 'capacity',
    statement: 'I tend to agree before checking my available capacity.',
    confidencePercent: 72,
    evidenceSummary: 'The same decision point appeared several times.',
    whyExplanation: 'The same decision point appears in saved moments.',
    section: ArchiveBeliefSection.changing,
    timeline: [
      for (var i = 0; i < quotes.length; i++)
        BeliefEvidenceQuote(periodLabel: 'Moment $i', quote: quotes[i]),
    ],
    conclusion: 'This response appears less automatic in recent moments.',
  );
  return ArchiveBeliefsSnapshot(
    homeBeliefs: [belief],
    current: const [],
    emerging: const [],
    changing: [belief],
    hiddenPatterns: const [],
    stats: const ArchiveBeliefStats(
      beliefsIdentified: 1,
      strongestBelief: 'capacity',
      archiveAgeDays: 7,
      reflectionsAnalysed: 5,
      evidencePoints: 5,
    ),
  );
}

Widget _harness({
  required ArchiveIntelligencePresentation presentation,
  ValueChanged<String>? onOpenMoment,
  ValueChanged<ArchiveIntelligenceAction>? onAction,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: ArchiveIntelligenceHome(
        presentation: presentation,
        onRefresh: () async {},
        onOpenMoment: onOpenMoment ?? (_) {},
        onAction: onAction ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders exactly four primary headings in order', (tester) async {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: _entries(),
      beliefs: _beliefs(),
    );
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_harness(presentation: presentation));

    const headings = [
      'What changed?',
      'Why ArchiveMe thinks that',
      'Supporting moments',
      'What to record or test next',
    ];
    var previousY = -1.0;
    for (final heading in headings) {
      expect(find.text(heading), findsOneWidget);
      final y = tester.getTopLeft(find.text(heading)).dy;
      expect(y, greaterThan(previousY));
      previousY = y;
    }
    expect(find.byKey(const Key('belief_history_timeline_card')), findsNothing);
    expect(
      find.byKey(const Key('archive_belief_proof_primary_card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('what_changed_since_last_time_card')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('archive_intelligence_next_action_button')),
      findsOneWidget,
    );
  });

  testWidgets('excludes administrative and promotional controls', (
    tester,
  ) async {
    final presentation = ArchiveIntelligencePresentation.build(
      entries: _entries(),
      beliefs: _beliefs(),
    );
    await tester.pumpWidget(_harness(presentation: presentation));

    for (final copy in [
      'Backup',
      'Restore',
      'Upgrade to Pro',
      'Beta feedback',
      'Set up check-in',
      'Weekly review',
      'Monthly report',
    ]) {
      expect(find.textContaining(copy), findsNothing);
    }
  });

  testWidgets('evidence opens its exact source entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? openedEntry;
    final presentation = ArchiveIntelligencePresentation.build(
      entries: _entries(),
      beliefs: _beliefs(),
    );
    await tester.pumpWidget(
      _harness(
        presentation: presentation,
        onOpenMoment: (entryId) => openedEntry = entryId,
      ),
    );

    final evidence = find.byKey(
      const ValueKey('archive_evidence_moment:entry-0'),
    );
    await tester.ensureVisible(evidence);
    await tester.tap(evidence);
    expect(openedEntry, 'entry-0');
  });

  testWidgets('empty and low-evidence states stay honest', (tester) async {
    final empty = ArchiveIntelligencePresentation.build(
      entries: const [],
      beliefs: null,
    );
    await tester.pumpWidget(_harness(presentation: empty));
    expect(find.byKey(const Key('archive_intelligence_empty')), findsOneWidget);
    expect(find.text('What changed?'), findsNothing);

    final low = ArchiveIntelligencePresentation.build(
      entries: _entries(),
      beliefs: _beliefs(lowEvidence: true),
    );
    await tester.pumpWidget(_harness(presentation: low));
    expect(find.textContaining('early read'), findsOneWidget);
    expect(find.textContaining('may change'), findsOneWidget);
  });

  for (final layout in [
    (size: const Size(320, 568), textScale: 1.0),
    (size: const Size(390, 844), textScale: 1.0),
    (size: const Size(390, 844), textScale: 2.0),
  ]) {
    testWidgets('does not overflow at ${layout.size.width.toInt()}x'
        '${layout.size.height.toInt()} scale ${layout.textScale}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(layout.size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final presentation = ArchiveIntelligencePresentation.build(
        entries: _entries(),
        beliefs: _beliefs(),
      );
      await tester.pumpWidget(
        _harness(presentation: presentation, textScale: layout.textScale),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('semantic section order matches visual hierarchy', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final presentation = ArchiveIntelligencePresentation.build(
      entries: _entries(),
      beliefs: _beliefs(),
    );
    await tester.pumpWidget(_harness(presentation: presentation));

    final sortKeys = <double>[];
    for (final title in [
      'What changed?',
      'Why ArchiveMe thinks that',
      'Supporting moments',
      'What to record or test next',
    ]) {
      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == title,
        ),
      );
      sortKeys.add((semantics.properties.sortKey! as OrdinalSortKey).order);
    }
    expect(sortKeys, [1, 2, 3, 4]);
  });
}
