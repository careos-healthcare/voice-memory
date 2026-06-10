import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/features/pressure_retention/pressure_check_in_record.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_engine.dart';
import 'package:voicememory_mobile/features/pressure_retention/thread_return_evidence_model.dart';
import 'package:voicememory_mobile/screens/pressure_insights_screen.dart';
import 'package:voicememory_mobile/widgets/pressure_retention/thread_return_evidence_card.dart';

final DateTime _base = DateTime(2026, 6, 9, 12);

PressureCheckInRecord _record({
  required String id,
  int daysAgo = 0,
  String optionId = 'could_not_stop',
  List<String> contextIds = const [],
  String? fear,
  String? stopCostNote,
}) {
  return PressureCheckInRecord(
    entryId: id,
    createdAt: _base.subtract(Duration(days: daysAgo)),
    optionId: optionId,
    contextIds: contextIds,
    fear: fear,
    stopCostNote: stopCostNote,
    transcript: 'pressure moment',
  );
}

/// Three work-context entries across 8 days, newest on the "today" base day.
List<PressureCheckInRecord> _workThread3() => [
      _record(
        id: 'a',
        daysAgo: 7,
        contextIds: const ['work'],
      ),
      _record(
        id: 'b',
        daysAgo: 3,
        contextIds: const ['work'],
        fear: 'The deadline slipping',
      ),
      _record(
        id: 'c',
        daysAgo: 0,
        contextIds: const ['work'],
        fear: 'I kept checking messages after I wanted to stop.',
      ),
    ];

/// Entries with no overlap at all: different options, no contexts, no notes.
List<PressureCheckInRecord> _unrelatedRecords() => [
      _record(id: 'u0', daysAgo: 2, optionId: 'could_not_stop'),
      _record(id: 'u1', daysAgo: 1, optionId: 'guilty_resting'),
      _record(id: 'u2', daysAgo: 0, optionId: 'had_to_prove_enough'),
    ];

void main() {
  const engine = ThreadReturnEvidenceEngine();

  group('Thread return evidence engine — eligibility', () {
    test('no evidence with fewer than 2 entries', () {
      expect(engine.build(const [], now: _base).hasEvidence, isFalse);
      expect(
        engine
            .build([_record(id: 'a', contextIds: const ['work'])], now: _base)
            .hasEvidence,
        isFalse,
      );
    });

    test('no evidence when nothing overlaps across entries', () {
      final evidence = engine.build(_unrelatedRecords(), now: _base);
      expect(evidence.hasEvidence, isFalse);
      expect(evidence.evidenceSnippets, isEmpty);
      expect(evidence.entryIds, isEmpty);
    });

    test('2 related entries produce early signal language only', () {
      final evidence = engine.build([
        _record(id: 'a', daysAgo: 5, contextIds: const ['work']),
        _record(id: 'b', daysAgo: 0, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.hasEvidence, isTrue);
      expect(evidence.status, ThreadReturnStatus.earlySignal);
      expect(evidence.statusLabel, 'Early signal');
      expect(evidence.headline, ThreadReturnEvidence.earlySignalHeadline);
      expect(evidence.summaryLine, contains('Too early'));
      expect(evidence.confidenceLabel,
          ThreadReturnEvidence.earlySignalConfidence);
      // Never stronger language with only 2 occurrences.
      final copy =
          '${evidence.headline} ${evidence.summaryLine}'.toLowerCase();
      expect(copy, isNot(contains('returned')));
      expect(copy, isNot(contains('building')));
    });
  });

  group('Thread return evidence engine — status rules', () {
    test('3 related entries with one today produce returned language', () {
      final evidence = engine.build(_workThread3(), now: _base);

      expect(evidence.hasEvidence, isTrue);
      expect(evidence.status, ThreadReturnStatus.returned);
      expect(evidence.statusLabel, 'Returned');
      expect(
        evidence.headline,
        ThreadReturnEvidence.returnedTodayHeadline,
      );
      expect(
        evidence.summaryLine,
        'Work pressure has appeared 3 times in 8 days.',
      );
    });

    test('repeated count, days window, and entry ids are correct', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(evidence.occurrenceCount, 3);
      expect(evidence.daysWindow, 8);
      expect(evidence.entryIds, ['a', 'b', 'c']);
      expect(evidence.confidenceLabel,
          ThreadReturnEvidence.repeatedSignalConfidence);
    });

    test('fading when older occurrences are stronger than recent', () {
      final evidence = engine.build([
        _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
        _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
        _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.status, ThreadReturnStatus.fading);
      expect(evidence.statusLabel, 'May be fading');
      expect(evidence.headline, ThreadReturnEvidence.fadingHeadline);
      expect(evidence.summaryLine, contains('less often'));
      expect(evidence.summaryLine, contains('Work pressure'));
    });

    test('building when recent occurrences are increasing', () {
      final evidence = engine.build([
        _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
        _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
        _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
      ], now: _base);

      expect(evidence.status, ThreadReturnStatus.building);
      expect(evidence.statusLabel, 'Building');
      expect(evidence.headline, ThreadReturnEvidence.buildingHeadline);
      expect(evidence.occurrenceCount, 4);
      expect(evidence.daysWindow, 8);
    });
  });

  group('Thread return evidence engine — evidence integrity', () {
    test('exact snippets from the user\u2019s entries are included', () {
      final evidence = engine.build(_workThread3(), now: _base);
      expect(
        evidence.evidenceSnippets,
        contains('I kept checking messages after I wanted to stop.'),
      );
      expect(evidence.evidenceSnippets, contains('The deadline slipping'));
    });

    test('snippets are capped at 3, newest first', () {
      final evidence = engine.build([
        for (var i = 0; i < 5; i++)
          _record(
            id: 's$i',
            daysAgo: i,
            contextIds: const ['work'],
            fear: 'Unique note number $i',
          ),
      ], now: _base);

      expect(evidence.evidenceSnippets.length, 3);
      expect(evidence.evidenceSnippets, [
        'Unique note number 0',
        'Unique note number 1',
        'Unique note number 2',
      ]);
    });

    test('source terms are capped at 3', () {
      final evidence = engine.build([
        for (var i = 0; i < 3; i++)
          _record(
            id: 't$i',
            daysAgo: i,
            contextIds: const ['work', 'evening', 'deadline'],
            fear: 'Endless email checking',
          ),
      ], now: _base);

      expect(evidence.sourceTerms.length, ThreadReturnEvidence.maxTerms);
      expect(evidence.sourceTerms.length, 3);
    });

    test('no fabricated snippets — every snippet exists in the records', () {
      final records = _workThread3();
      final evidence = engine.build(records, now: _base);
      final realText = {
        for (final record in records) ...[
          if (record.fear != null) record.fear!.trim(),
          if (record.stopCostNote != null) record.stopCostNote!.trim(),
        ],
      };
      expect(evidence.evidenceSnippets, isNotEmpty);
      for (final snippet in evidence.evidenceSnippets) {
        expect(realText, contains(snippet),
            reason: 'snippet "$snippet" must come from a real entry');
      }
    });

    test('entries without free text produce no snippets, never filler', () {
      final evidence = engine.build([
        _record(id: 'n0', daysAgo: 2, contextIds: const ['work']),
        _record(id: 'n1', daysAgo: 1, contextIds: const ['work']),
        _record(id: 'n2', daysAgo: 0, contextIds: const ['work']),
      ], now: _base);
      expect(evidence.hasEvidence, isTrue);
      expect(evidence.evidenceSnippets, isEmpty);
    });
  });

  group('Thread return evidence — language guardrails', () {
    test('no diagnostic, certainty, or shame wording in any status', () {
      final scenarios = [
        engine.build(_workThread3(), now: _base),
        engine.build([
          _record(id: 'f0', daysAgo: 8, contextIds: const ['work']),
          _record(id: 'f1', daysAgo: 7, contextIds: const ['work']),
          _record(id: 'f2', daysAgo: 6, contextIds: const ['work']),
          _record(id: 'f3', daysAgo: 1, contextIds: const ['work']),
        ], now: _base),
        engine.build([
          _record(id: 'b0', daysAgo: 8, contextIds: const ['work']),
          _record(id: 'b1', daysAgo: 3, contextIds: const ['work']),
          _record(id: 'b2', daysAgo: 2, contextIds: const ['work']),
          _record(id: 'b3', daysAgo: 1, contextIds: const ['work']),
        ], now: _base),
        engine.build([
          _record(id: 'e0', daysAgo: 5, contextIds: const ['work']),
          _record(id: 'e1', daysAgo: 0, contextIds: const ['work']),
        ], now: _base),
      ];

      for (final evidence in scenarios) {
        final copy = [
          evidence.headline,
          evidence.summaryLine,
          evidence.statusLabel,
          evidence.confidenceLabel,
          ...evidence.sourceTerms,
          ThreadReturnEvidence.evidenceHeading,
          ThreadReturnEvidence.basedOnLine,
        ].join(' ').toLowerCase();
        for (final banned in const [
          'definitely',
          'always',
          'certain',
          'guaranteed',
          'proven',
          'diagnos',
          'disorder',
          'must',
          'failure',
          'lazy',
          'weak',
          'shame',
        ]) {
          expect(copy, isNot(contains(banned)),
              reason: 'copy must not contain "$banned"');
        }
      }
    });

    test('no VoiceMemory in any consumer copy', () {
      final evidence = engine.build(_workThread3(), now: _base);
      final copy = [
        evidence.headline,
        evidence.summaryLine,
        evidence.statusLabel,
        evidence.confidenceLabel,
        ...evidence.sourceTerms,
        ...evidence.evidenceSnippets,
        ThreadReturnEvidence.evidenceHeading,
        ThreadReturnEvidence.basedOnLine,
      ].join(' ');
      expect(copy, isNot(contains('VoiceMemory')));
    });
  });

  group('Thread return evidence card', () {
    testWidgets('renders headline, summary, chips, evidence, and footer',
        (tester) async {
      final evidence = engine.build(_workThread3(), now: _base);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThreadReturnEvidenceCard(evidence: evidence),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('This thread returned today'), findsOneWidget);
      expect(
        find.text('Work pressure has appeared 3 times in 8 days.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('thread_return_status_chip')),
        findsOneWidget,
      );
      expect(find.text('Returned'), findsOneWidget);
      expect(find.text(evidence.confidenceLabel), findsOneWidget);
      for (final term in evidence.sourceTerms) {
        expect(find.text(term), findsOneWidget);
      }
      expect(find.text('Evidence behind this'), findsOneWidget);
      for (final snippet in evidence.evidenceSnippets) {
        expect(find.textContaining(snippet), findsOneWidget);
      }
      expect(find.text('Based on your recent archive'), findsOneWidget);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('renders nothing without evidence', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ThreadReturnEvidenceCard(
              evidence: ThreadReturnEvidence.none(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );
    });
  });

  group('Pressure Insights integration', () {
    testWidgets('renders the thread card near the top when eligible',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 4200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              ..._workThread3(),
              _record(id: 'd', daysAgo: 1, contextIds: const ['work']),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const Key('thread_return_evidence_card'));
      expect(cardFinder, findsOneWidget);

      // Existing pattern reveal card is still shown, below the thread card.
      final revealFinder =
          find.byKey(const Key('pressure_pattern_reveal_card'));
      expect(revealFinder, findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder).dy,
        lessThan(tester.getTopLeft(revealFinder).dy),
      );
    });

    testWidgets('hides the thread card when not eligible', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: PressureInsightsScreen(
            entitlementReader: FakeArchiveEntitlementReader(pro: false),
            records: [
              _record(id: 'x0', daysAgo: 1, optionId: 'could_not_stop'),
              _record(id: 'x1', daysAgo: 0, optionId: 'guilty_resting'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('thread_return_evidence_card')),
        findsNothing,
      );
    });
  });
}
